#!/usr/bin/env python3
"""spec-loop-queue.py — eligibility queue for /sdd-spec-loop (spec v137, AC-1, AC-2).

Reads specs/README.md checklists and specs/spec-v{N}-*.md frontmatter, prints the specs the loop may build
(ranked: in progress first, then fewest tasks left) and every excluded spec with its reason. Read-only.

Usage: spec-loop-queue.py [--specs-dir DIR] [--owner EMAIL] [--include-unowned] [--json]
Exit 0 always on readable input; exit 2 if specs/README.md is missing.
"""
import argparse, json, os, re, subprocess, sys

HEADER = re.compile(r'^##\s+v(\d+(?:\.\d+)?)\s*[:—–-]\s*(.*)$')
LOOSE_HEADER = re.compile(r'^##\s+v\d')
BOX = re.compile(r'^\s*-\s+\[( |x|X)\]\s+(.*)$')
DEAD_STATUS = {'complete', 'completed', 'paused', 'superseded', 'closed', 'cancelled', 'archived', 'retired', 'abandoned'}


def log(step, outcome, **kw):
    """Structured log line on stderr (AP-002/AP-007)."""
    extra = ' '.join(f'{k}={v}' for k, v in kw.items())
    run = os.environ.get('SPEC_LOOP_RUN_ID', '-')
    print(f'spec-loop-queue run={run} step={step} outcome={outcome} {extra}'.rstrip(), file=sys.stderr)


def parse_frontmatter(path):
    fm = {}
    try:
        lines = open(path, encoding='utf-8').read().splitlines()
    except OSError as e:
        raise RuntimeError(f'cannot read {path}: {e}')
    if not lines or lines[0].strip() != '---':
        return fm
    for ln in lines[1:]:
        if ln.strip() == '---':
            break
        m = re.match(r'^([A-Za-z_][\w-]*):\s*(.*)$', ln)
        if m:
            v = m.group(2).split(' #')[0].strip().strip('"\'')
            fm[m.group(1)] = v
    return fm


def parse_list(v):
    v = (v or '').strip().strip('[]')
    return [x.strip().strip('"\'') for x in v.split(',') if x.strip()]


def norm_ver(v):
    m = re.search(r'(\d+(?:\.\d+)?)', str(v))
    return 'v' + m.group(1) if m else str(v)


def parse_readme(path):
    """Return (specs, unreadable) where specs maps vN -> {name, done, total, tasks:[(checked,text)]}."""
    specs, unreadable, cur = {}, [], None
    for ln in open(path, encoding='utf-8').read().splitlines():
        m = HEADER.match(ln)
        if m:
            cur = 'v' + m.group(1)
            specs[cur] = {'name': m.group(2).strip(), 'done': 0, 'total': 0, 'tasks': []}
            continue
        if LOOSE_HEADER.match(ln):
            unreadable.append(ln.strip())
            cur = None
            continue
        if ln.startswith('## '):
            cur = None  # a non-spec H2 ends the section
            continue
        b = BOX.match(ln)
        if b and cur:
            checked = b.group(1) != ' '
            specs[cur]['tasks'].append((checked, b.group(2)))
            specs[cur]['total'] += 1
            specs[cur]['done'] += checked
    return specs, unreadable


def find_spec_file(specs_dir, ver):
    n = ver[1:]
    for d in (specs_dir, os.path.join(specs_dir, 'completed')):
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if re.match(rf'^spec-v{re.escape(n)}-.*\.md$', f):
                return os.path.join(d, f)
    return None


def default_owner():
    here = os.path.dirname(os.path.abspath(__file__))
    for cmd in ([os.path.join(here, 'user-email.sh'), 'get'], ['git', 'config', 'user.email']):
        try:
            out = subprocess.run(cmd, capture_output=True, text=True, timeout=10).stdout.strip()
            if out:
                return out
        except (OSError, subprocess.SubprocessError) as e:
            log('owner', 'fallback', source=' '.join(cmd[-2:]), error=e)
            continue
    return ''


def build(specs_dir, owner, include_unowned):
    readme = os.path.join(specs_dir, 'README.md')
    if not os.path.isfile(readme):
        raise FileNotFoundError(f'{readme} not found')
    specs, unreadable = parse_readme(readme)
    status_of = {v: ('complete' if s['total'] and s['done'] == s['total'] else 'open') for v, s in specs.items()}
    queue, excluded = [], []
    for row in unreadable:
        excluded.append({'version': row[:40], 'name': '', 'reason': 'unreadable row'})
    for ver, s in specs.items():
        def ex(reason):
            excluded.append({'version': ver, 'name': s['name'], 'reason': reason})
        if s['total'] == 0:
            ex('no tasks'); continue
        if s['done'] == s['total']:
            ex('complete'); continue
        path = find_spec_file(specs_dir, ver)
        if not path:
            ex('spec file missing'); continue
        try:
            fm = parse_frontmatter(path)
        except RuntimeError as e:
            ex(f'unreadable spec file ({e})'); continue
        st = fm.get('status', '').lower()
        if st in DEAD_STATUS:
            ex(f'status {st}'); continue
        sowner = fm.get('owner', '').strip()
        if sowner and owner and sowner.lower() != owner.lower():
            ex(f'owned by {sowner}'); continue
        if not sowner and not include_unowned:
            ex('unowned (project has not opted in)'); continue
        deps = [norm_ver(d) for d in parse_list(fm.get('depends_on', ''))]
        pending = [d for d in deps if status_of.get(d) != 'complete' and not (find_spec_file(specs_dir, d) or '').startswith(os.path.join(specs_dir, 'completed'))]
        if pending:
            ex('depends on incomplete ' + ', '.join(pending)); continue
        nxt = next(((i, t) for i, (c, t) in enumerate(s['tasks']) if not c), None)
        if nxt and re.search(r'\(blocked:', nxt[1], re.I):
            ex('external blocker: ' + nxt[1][nxt[1].lower().index('(blocked:'):][:80]); continue
        queue.append({'version': ver, 'name': s['name'], 'done': s['done'], 'total': s['total'],
                      'left': s['total'] - s['done'], 'in_progress': s['done'] > 0,
                      'next_task': nxt[1] if nxt else '', 'spec_file': path})
    queue.sort(key=lambda q: (not q['in_progress'], q['left'], float(q['version'][1:])))
    return queue, excluded


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--specs-dir', default='specs')
    ap.add_argument('--owner', default=None)
    ap.add_argument('--include-unowned', action='store_true')
    ap.add_argument('--json', action='store_true')
    a = ap.parse_args(argv)
    owner = a.owner if a.owner is not None else default_owner()
    try:
        queue, excluded = build(a.specs_dir, owner, a.include_unowned)
    except (OSError, UnicodeDecodeError) as e:
        log('queue', 'error', error=e)
        print(f'ERROR: {e}', file=sys.stderr)
        return 2
    log('queue', 'ok', eligible=len(queue), excluded=len(excluded), owner=owner or '-')
    if a.json:
        print(json.dumps({'owner': owner, 'queue': queue, 'excluded': excluded}, indent=2))
        return 0
    print(f'Eligible ({len(queue)}) — owner: {owner or "(none)"}')
    for i, q in enumerate(queue, 1):
        print(f'{i}. {q["version"]}\t{q["done"]}/{q["total"]}\t{q["name"]}\n   next: {q["next_task"][:140]}')
    print(f'\nExcluded ({len(excluded)})')
    for e in excluded:
        print(f'- {e["version"]}\t{e["reason"]}')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
