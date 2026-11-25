#!/usr/bin/env python3
"""spec-loop-gates.py — config, gate classifier and parked-question writer for /sdd-spec-loop (spec v137).

Subcommands:
  config   [--file .aid/config.yaml]            print the effective spec-loop config as JSON (AC-11).
  classify [--file F] [--json] [--stdin] [TEXT...]
                                                classify task text(s): buildable or gated, with gate kind.
                                                --stdin reads one task per line (use this for text from a spec:
                                                task text contains backticks/quotes the shell would expand).
  park     --run-dir D --spec vN (--task TEXT | --stdin) [--kind K]
                                                append a parked question (AC-4) to D/parked.jsonl and D/parked.md.
  parked   --run-dir D                          print parked questions as JSON lines, in order (for AC-10).

Conservative by design: a task is buildable only if it matches a known repo-local build verb AND no gate
pattern. Anything unclassifiable is gated. Open Question 2 (resolved): commit/push is gated unless the project's
config sets allow_commit; no other gate can be pre-approved; projects may only ADD gates (extra_gates).

Config (.aid/config.yaml), all keys optional:
  spec-loop:
    owner_rule: mine            # mine | mine_or_unowned
    allow_commit: false
    test_command: ""            # empty = tests/run-all.sh if present, else none
    max_passes: 4
    extra_gates: [clinical threshold, rule config]
"""
import argparse, json, os, re, sys, datetime

DEFAULTS = {'owner_rule': 'mine', 'allow_commit': False, 'test_command': '', 'max_passes': 4, 'extra_gates': []}

# (kind, regex, who decides, what each answer changes, recommended)
GATES = [
    ('global-config', r'~/\.claude|\bcreate (a )?(git )?branch\b|\bnew branch\b|\bgit branch\b|/aid-update|\baid-update\b',
     'the developer', 'Approve: the change touches global or shared state. Decline: leave it for a manual step.', 'Decline; do it manually'),
    ('deploy', r'\bdeploy|\bpromote\b|\brelease\b|\bpublish\b|\bterraform\b|\bcloudformation\b|\binfrastructure\b|\biam\b|\bpermissions?\b',
     'the developer', 'Approve: something goes live. Decline: the task stays open.', 'Decline until a person runs it'),
    ('environment-write', r'\bmigrat(e|ion)\b|\bproduction\b|\bprod\b|\bdev (check|environment|env)\b|\bstaging\b|\bbucket\b|\b(real|live) (data|environment)\b|\bdatabase write|\bbackfill\b',
     'the developer', 'Approve: data is written to a real environment. Decline: stays open.', 'Decline until a person checks'),
    ('message', r'\bsend\b|\bemail\b|\be-mail\b|\bslack\b|\bgchat\b|\breply\b|\bdraft reply\b|\bcomment on\b|\bpost (a|the|to)\b|\bopen (a|an) (pr|issue)\b|\bpull request\b|\bgh (issue|pr)\b',
     'the developer', 'Approve: an outbound message or external artifact is created. Decline: stays open.', 'Decline; the developer sends it'),
    ('destructive', r'\bdelete\b|\bremove (the )?(file|dir|folder)|\brm\b|\bdrop\b|\bforce[- ]push\b|\breset --hard\b|\bpurge\b|\bwipe\b',
     'the developer', 'Approve: something is destroyed. Decline: stays open.', 'Decline; the developer deletes it'),
    ('sign-off', r'\bconfirm\b|\bdecide\b|\bdecision\b|\bresolve\b.*\bopen question|\bsign[- ]?off\b|\bapprov|\breviewed by\b|\bpresent\b|\bask\b|\bwhether\b|\bwith (bob|the developer|the user)\b|\bfirst real run\b',
     'a person (named in the task, else the developer)', 'The answer is recorded and the task is then buildable or closed.', 'Ask at the end of the run'),
]
COMMIT = ('commit-push', r'\bcommit\b|\bpush\b|\bgit add\b',
          'the developer (or set allow_commit in config)', 'Approve: changes are committed or pushed. Decline: left in the working tree.', 'Allow commit only on a passing test run')
BUILD = re.compile(r'^\W*(add|create|write|implement|fix|update|extend|refactor|document|draft|make|wire|define|rewrite|rename|replace|change|record|list|include|ensure|teach|support|parse|emit|test|tests|cover|handle|use|read|apply|bump|expose|surface|show|print|log)\b', re.I)
BUILD_ANY = re.compile(r'`[^`]*\.(md|sh|py|json|yaml|yml|js|ts)`|\btests?\b|\bscript\b|\bskill\b|\bdoc(s|umentation)?\b', re.I)


def log(step, outcome, **kw):
    extra = ' '.join(f'{k}={v}' for k, v in kw.items())
    run = os.environ.get('SPEC_LOOP_RUN_ID', '-')
    print(f'spec-loop-gates run={run} step={step} outcome={outcome} {extra}'.rstrip(), file=sys.stderr)


def _val(v):
    v = v.split(' #')[0].strip()
    if v.startswith('[') and v.endswith(']'):
        return [x.strip().strip('"\'') for x in v[1:-1].split(',') if x.strip()]
    v = v.strip('"\'')
    if v.lower() in ('true', 'false'):
        return v.lower() == 'true'
    if re.fullmatch(r'-?\d+', v):
        return int(v)
    return v


def load_config(path='.aid/config.yaml'):
    cfg = dict(DEFAULTS)
    if not os.path.isfile(path):
        return cfg
    try:
        lines = open(path, encoding='utf-8').read().splitlines()
    except OSError as e:
        log('config', 'unreadable', error=e)
        return cfg
    inside = False
    for ln in lines:
        if re.match(r'^spec-loop:\s*(#.*)?$', ln):
            inside = True
            continue
        if inside:
            if ln.strip() == '' or ln.lstrip().startswith('#'):
                continue
            if not ln.startswith((' ', '\t')):
                break
            m = re.match(r'^\s+([A-Za-z_]+):\s*(.*)$', ln)
            if m and m.group(1) in DEFAULTS:
                cfg[m.group(1)] = _val(m.group(2))
            elif m:
                log('config', 'unknown-key', key=m.group(1))
    if cfg['owner_rule'] not in ('mine', 'mine_or_unowned'):
        log('config', 'bad-owner-rule', value=cfg['owner_rule'], using='mine')
        cfg['owner_rule'] = 'mine'
    if not isinstance(cfg['extra_gates'], list):
        cfg['extra_gates'] = [str(cfg['extra_gates'])]
    if not isinstance(cfg['max_passes'], int) or cfg['max_passes'] < 1:
        cfg['max_passes'] = DEFAULTS['max_passes']
    if not isinstance(cfg['allow_commit'], bool):
        cfg['allow_commit'] = False
    return cfg


def classify(text, cfg):
    t = text or ''
    for kind, rx, who, changes, rec in GATES:
        if re.search(rx, t, re.I):
            return {'gated': True, 'kind': kind, 'who': who, 'changes': changes, 'recommended': rec}
    for extra in cfg['extra_gates']:
        if extra and extra.lower() in t.lower():
            return {'gated': True, 'kind': 'project-gate', 'who': 'the developer',
                    'changes': f'Project gate "{extra}": approve to perform, decline to leave open.', 'recommended': 'Decline until a person decides'}
    kind, rx, who, changes, rec = COMMIT
    if re.search(rx, t, re.I) and not cfg['allow_commit']:
        return {'gated': True, 'kind': kind, 'who': who, 'changes': changes, 'recommended': rec}
    if BUILD.search(t) or BUILD_ANY.search(t) or re.search(rx, t, re.I):
        return {'gated': False, 'kind': 'buildable', 'who': '', 'changes': '', 'recommended': ''}
    return {'gated': True, 'kind': 'unclassified', 'who': 'the developer',
            'changes': 'The loop could not tell what this task does, so it will not do it unasked.', 'recommended': 'Decline; run it by hand or reword the task'}


def park(run_dir, spec, task, kind, cfg):
    c = classify(task, cfg)
    if kind:
        c['kind'] = kind
    entry = {'when': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'), 'spec': spec, 'task': task,
             'gate_kind': c['kind'], 'who_decides': c['who'] or 'the developer', 'what_each_answer_changes': c['changes'] or 'Unknown.',
             'recommended': c['recommended'] or 'Decline'}
    try:
        os.makedirs(run_dir, exist_ok=True)
        with open(os.path.join(run_dir, 'parked.jsonl'), 'a', encoding='utf-8') as f:
            f.write(json.dumps(entry) + '\n')
        with open(os.path.join(run_dir, 'parked.md'), 'a', encoding='utf-8') as f:
            f.write(f'## {spec} — {entry["gate_kind"]}\n\n- Task: {task}\n- Who decides: {entry["who_decides"]}\n'
                    f'- What each answer changes: {entry["what_each_answer_changes"]}\n- Recommended: {entry["recommended"]}\n\n')
    except OSError as e:
        log('park', 'error', error=e)
        print(f'ERROR: cannot write parked question in {run_dir}: {e}', file=sys.stderr)
        return 2
    log('park', 'ok', spec=spec, kind=entry['gate_kind'])
    print(json.dumps(entry))
    return 0


def read_parked(run_dir):
    p = os.path.join(run_dir, 'parked.jsonl')
    if not os.path.isfile(p):
        return 0
    for n, ln in enumerate(open(p, encoding='utf-8'), 1):
        if not ln.strip():
            continue
        try:
            print(json.dumps(json.loads(ln)))
        except json.JSONDecodeError as e:
            print(f'ERROR: {p}:{n}: malformed ({e.msg})', file=sys.stderr)
            return 2
    return 0


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('cmd', choices=['config', 'classify', 'park', 'parked'])
    ap.add_argument('text', nargs='*')
    ap.add_argument('--file', default='.aid/config.yaml')
    ap.add_argument('--json', action='store_true')
    ap.add_argument('--run-dir')
    ap.add_argument('--spec')
    ap.add_argument('--task')
    ap.add_argument('--kind')
    ap.add_argument('--stdin', action='store_true', help='read task text from stdin (park: whole input; classify: one per line)')
    a = ap.parse_args(argv)
    cfg = load_config(a.file)
    if a.cmd == 'config':
        print(json.dumps(cfg, indent=2))
        return 0
    stdin_text = sys.stdin.read() if a.stdin else None
    if a.cmd == 'classify':
        texts = list(a.text) + ([l for l in stdin_text.splitlines() if l.strip()] if stdin_text is not None else [])
        for t in texts:
            c = classify(t, cfg)
            print(json.dumps(dict(c, task=t)) if a.json else f'{"GATED   " if c["gated"] else "BUILDABLE"}\t{c["kind"]}\t{t}')
        return 0
    if not a.run_dir:
        print('ERROR: --run-dir required', file=sys.stderr)
        return 2
    if a.cmd == 'park':
        task = stdin_text.strip() if stdin_text is not None else a.task
        if not (a.spec and task):
            print('ERROR: park needs --spec and --task (or --stdin)', file=sys.stderr)
            return 2
        return park(a.run_dir, a.spec, task, a.kind, cfg)
    return read_parked(a.run_dir)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
