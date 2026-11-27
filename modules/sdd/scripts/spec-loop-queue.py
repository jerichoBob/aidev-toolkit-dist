#!/usr/bin/env python3
"""spec-loop-queue.py — eligibility queue for /sdd-spec-loop (spec v137, AC-1, AC-2).

Reads specs/README.md checklists and specs/spec-v{N}-*.md frontmatter, prints the specs the loop may build
(ranked by the chosen priority strategy) and every excluded spec with its reason. Read-only.

Usage: spec-loop-queue.py [--specs-dir DIR] [--owner EMAIL] [--include-unowned] [--json]
                          [--priority STRATEGY] [--work-order-file FILE] [--categories-file FILE] [--config FILE]
                          [--check-categories]
Exit 0 always on readable input; exit 2 if specs/README.md (or a requested work-order file) is missing.

--check-categories (spec v139): read-only; compares every spec file in specs/ and specs/completed/ with the versions named in
the categories table and prints `missing`, `fresh` or `stale`, then `unlisted:` and `dangling:` version lists (or JSON with
--json). A version in the table may carry a trailing `*` to mark it completed. Exit 0 for all three outcomes.

Priority strategies (flag overrides `priority` in the spec-loop section of .aid/config.yaml; default `default`):
  default       in progress first, then fewest tasks left, then lowest version.
  oldest        lowest version number first.
  newest        highest version number first.
  fewest-gated  fewest unchecked tasks the loop must park (gated or already blocked) first, then default order.
                Surfaces the specs the loop can build most of, so passes are not spent parking.
  roi           highest value per unit of work first. value = the spec's `value:` frontmatter, else its category's Value in
                `categories_file` (default specs/spec-categories.md), else 3 (all 1-5);
                cost = buildable tasks left + `gated_cost` (default 2.0) per gated task, because a gate stops the automation
                and costs you a question. A spec with nothing buildable scores 0. Ties use the default order.
                The text output prints value (and its source), buildable and gated counts, cost, the score and the
                gate kinds that are dragging it down, so the order can be checked by hand.
  work-order    follow the order listed in a work-order file (`work_order_file` in config, default
                specs/work-order.md): one spec per line, `v12` or `- v12`, `#` comments and blank lines ignored.
                Specs not listed follow, in default order.
"""
import argparse, importlib.util, json, os, re, subprocess, sys

STRATEGIES = ('default', 'oldest', 'newest', 'fewest-gated', 'roi', 'work-order')
DEFAULT_CATEGORIES = os.path.join('specs', 'spec-categories.md')
DEFAULT_VALUE = 3.0
GATED_COST = 2.0  # a gated task is a human interruption: it costs more than a task the loop builds
DEFAULT_WORK_ORDER = os.path.join('specs', 'work-order.md')

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


def load_gates():
    """Import the sibling gate classifier (hyphenated filename, so importlib)."""
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'spec-loop-gates.py')
    spec = importlib.util.spec_from_file_location('spec_loop_gates', path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def parse_work_order(path):
    """Return versions in file order. Raises OSError if unreadable."""
    order = []
    for ln in open(path, encoding='utf-8').read().splitlines():
        ln = ln.split('#')[0].strip()
        m = re.match(r'^(?:[-*]\s+)?(?:\[[ xX]\]\s+)?v?(\d+(?:\.\d+)?)\b', ln)
        if m and 'v' + m.group(1) not in order:
            order.append('v' + m.group(1))
    return order


def category_rows(path):
    """Yield (cells, specs_idx, value_idx) for each data row of the categories table. Raises OSError if unreadable."""
    cols = None
    for ln in open(path, encoding='utf-8').read().splitlines():
        if not ln.startswith('|'):
            cols = None
            continue
        cells = [c.strip() for c in ln.strip().strip('|').split('|')]
        if cols is None:
            low = [c.lower() for c in cells]
            if 'specs' in low and 'value' in low:
                cols = (low.index('specs'), low.index('value'))
            continue
        if set(''.join(cells)) <= set('-: '):
            continue
        yield cells, cols[0], cols[1]


def parse_categories(path):
    """Return {vN: value} from a markdown table with `Specs` and `Value` columns. {} if absent/unreadable (logged).
    A version may carry a trailing `*` to mark it completed; the value still applies."""
    out = {}
    try:
        for cells, si, vi in category_rows(path):
            try:
                val = float(cells[vi])
            except (ValueError, IndexError):
                log('categories', 'bad-value', row=cells[0] if cells else '?')
                continue
            if not 1 <= val <= 5:
                log('categories', 'bad-value', row=cells[0], value=val)
                continue
            for v in re.findall(r'\bv(\d+(?:\.\d+)?)\b', cells[si]):
                out['v' + v] = val
    except OSError as e:
        log('categories', 'unreadable', path=path, error=e)
        return {}
    if not out:
        log('categories', 'empty', path=path)
    return out


def spec_versions(specs_dir):
    """Versions of every spec file in specs/ and specs/completed/ (sorted by number)."""
    found = set()
    for d in (specs_dir, os.path.join(specs_dir, 'completed')):
        if os.path.isdir(d):
            for f in os.listdir(d):
                m = re.match(r'^spec-v(\d+(?:\.\d+)?)-.*\.md$', f)
                if m:
                    found.add('v' + m.group(1))
    return sorted(found, key=lambda v: float(v[1:]))


def check_categories(specs_dir, path):
    """Compare spec files with the categories table. Returns {'outcome', 'unlisted', 'dangling'}.
    missing = no readable table rows; stale = specs unlisted or rows naming specs with no file; else fresh."""
    on_disk = spec_versions(specs_dir)
    listed = set()
    try:
        for cells, si, _ in category_rows(path):
            listed.update('v' + v for v in re.findall(r'\bv(\d+(?:\.\d+)?)\b', cells[si]))
    except OSError as e:
        log('categories', 'unreadable', path=path, error=e)
    if not listed:
        return {'outcome': 'missing', 'unlisted': on_disk, 'dangling': []}
    unlisted = [v for v in on_disk if v not in listed]
    dangling = sorted((v for v in listed if v not in set(on_disk)), key=lambda v: float(v[1:]))
    return {'outcome': 'stale' if unlisted or dangling else 'fresh', 'unlisted': unlisted, 'dangling': dangling}


def rank(queue, strategy, specs, gates_cfg=None, work_order=None, cat_values=None):
    """Sort queue in place for the strategy. specs maps vN -> parsed README entry (for task text)."""
    num = lambda q: float(q['version'][1:])
    default = lambda q: (not q['in_progress'], q['left'], num(q))
    if strategy == 'oldest':
        queue.sort(key=num)
    elif strategy == 'newest':
        queue.sort(key=lambda q: -num(q))
    elif strategy in ('fewest-gated', 'roi'):
        gates = load_gates()
        for q in queue:
            tasks = [t for c, t in specs[q['version']]['tasks'] if not c]
            kinds = {}
            for t in tasks:
                if re.search(r'\(blocked:', t, re.I):
                    kinds['blocked'] = kinds.get('blocked', 0) + 1
                else:
                    c = gates.classify(t, gates_cfg)
                    if c['gated']:
                        kinds[c['kind']] = kinds.get(c['kind'], 0) + 1
            q['gate_kinds'] = kinds
            q['gated'] = sum(kinds.values())
        if strategy == 'fewest-gated':
            queue.sort(key=lambda q: (q['gated'],) + default(q))
        else:
            gated_cost = float((gates_cfg or {}).get('gated_cost', GATED_COST))
            for q in queue:
                if q['value_explicit']:
                    q['value_source'] = 'frontmatter'
                elif q['version'] in (cat_values or {}):
                    q['value'] = cat_values[q['version']]; q['value_source'] = 'category'
                else:
                    q['value'] = DEFAULT_VALUE; q['value_source'] = 'default'
                buildable = q['left'] - q['gated']
                cost = buildable + gated_cost * q['gated']
                q['buildable'] = buildable
                q['gated_cost'] = gated_cost
                q['cost'] = round(cost, 3)
                q['roi'] = round(q['value'] / cost, 3) if buildable > 0 else 0.0
            queue.sort(key=lambda q: (-q['roi'],) + default(q))
    elif strategy == 'work-order':
        pos = {v: i for i, v in enumerate(work_order or [])}
        queue.sort(key=lambda q: (pos.get(q['version'], len(pos)),) + default(q))
    else:
        queue.sort(key=default)


def build(specs_dir, owner, include_unowned, strategy='default', gates_cfg=None, work_order=None, cat_values=None):
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
        explicit = 'value' in fm
        try:
            value = float(fm.get('value', DEFAULT_VALUE))
            if not 1 <= value <= 5:
                raise ValueError(value)
        except ValueError:
            log('value', 'bad-value', spec=ver, value=fm.get('value'), using=DEFAULT_VALUE)
            value = DEFAULT_VALUE
        queue.append({'version': ver, 'value': value, 'value_explicit': explicit, 'name': s['name'], 'done': s['done'], 'total': s['total'],
                      'left': s['total'] - s['done'], 'in_progress': s['done'] > 0,
                      'next_task': nxt[1] if nxt else '', 'spec_file': path})
    rank(queue, strategy, specs, gates_cfg, work_order, cat_values)
    return queue, excluded


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--specs-dir', default='specs')
    ap.add_argument('--owner', default=None)
    ap.add_argument('--include-unowned', action='store_true')
    ap.add_argument('--json', action='store_true')
    ap.add_argument('--priority', default=None, help='|'.join(STRATEGIES))
    ap.add_argument('--work-order-file', default=None)
    ap.add_argument('--categories-file', default=None)
    ap.add_argument('--check-categories', action='store_true', help='report missing|fresh|stale for the categories file and exit')
    ap.add_argument('--config', default='.aid/config.yaml')
    a = ap.parse_args(argv)
    if a.check_categories:
        try:
            cfg = load_gates().load_config(a.config)
        except (OSError, UnicodeDecodeError) as e:
            log('categories', 'error', error=e)
            print(f'ERROR: {e}', file=sys.stderr)
            return 2
        res = check_categories(a.specs_dir, a.categories_file or cfg.get('categories_file') or DEFAULT_CATEGORIES)
        log('categories', res['outcome'], unlisted=len(res['unlisted']), dangling=len(res['dangling']))
        if a.json:
            print(json.dumps(res, indent=2))
        else:
            print(res['outcome'])
            print('unlisted: ' + ' '.join(res['unlisted']))
            print('dangling: ' + ' '.join(res['dangling']))
        return 0
    owner = a.owner if a.owner is not None else default_owner()
    try:
        gates = load_gates()
        cfg = gates.load_config(a.config)
        strategy = a.priority if a.priority is not None else cfg.get('priority', 'default')
        if strategy not in STRATEGIES:
            print(f'ERROR: unknown priority "{strategy}" (use one of: {", ".join(STRATEGIES)})', file=sys.stderr)
            log('queue', 'error', error=f'unknown priority {strategy}')
            return 2
        work_order = None
        if strategy == 'work-order':
            wo = a.work_order_file or cfg.get('work_order_file') or DEFAULT_WORK_ORDER
            work_order = parse_work_order(wo)
        cat_values = None
        if strategy == 'roi':
            cat_values = parse_categories(a.categories_file or cfg.get('categories_file') or DEFAULT_CATEGORIES)
        queue, excluded = build(a.specs_dir, owner, a.include_unowned, strategy, cfg, work_order, cat_values)
    except (OSError, UnicodeDecodeError) as e:
        log('queue', 'error', error=e)
        print(f'ERROR: {e}', file=sys.stderr)
        return 2
    log('queue', 'ok', eligible=len(queue), excluded=len(excluded), owner=owner or '-', priority=strategy)
    if a.json:
        print(json.dumps({'owner': owner, 'priority': strategy, 'queue': queue, 'excluded': excluded}, indent=2))
        return 0
    print(f'Eligible ({len(queue)}) — owner: {owner or "(none)"} — priority: {strategy}')
    for i, q in enumerate(queue, 1):
        print(f'{i}. {q["version"]}\t{q["done"]}/{q["total"]}\t{q["name"]}\n   next: {q["next_task"][:140]}')
        if 'roi' in q:
            gk = ', '.join(f'{k} x{n}' for k, n in sorted(q['gate_kinds'].items())) or 'none'
            print(f'   roi {q["roi"]:.3f} = value {q["value"]:g} ({q["value_source"]}) / cost {q["cost"]:g}'
                  f' ({q["buildable"]} buildable + {q["gated"]} gated x {q["gated_cost"]:g})   gates: {gk}')
        elif 'gated' in q:
            gk = ', '.join(f'{k} x{n}' for k, n in sorted(q['gate_kinds'].items())) or 'none'
            print(f'   gated {q["gated"]} of {q["left"]} left   gates: {gk}')
    print(f'\nExcluded ({len(excluded)})')
    for e in excluded:
        print(f'- {e["version"]}\t{e["reason"]}')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
