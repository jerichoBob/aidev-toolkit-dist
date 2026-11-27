#!/usr/bin/env python3
"""spec-categories-render.py — render specs/spec-categories.md from a category grouping (spec v139).

The grouping (which spec belongs to which use-case category, and the analysis text) is judgment and comes from the model
as a JSON file; everything mechanical happens here: completed specs get a trailing `*`, counts are computed, the Value of a
category already in the output file is kept (a new category uses the `value` in the JSON), and nothing is written unless every
spec file in specs/ and specs/completed/ is listed in exactly one category.

Usage: spec-categories-render.py --grouping FILE.json [--specs-dir specs] [--out specs/spec-categories.md]
                                 [--date YYYY-MM-DD] [--dry-run]
Grouping JSON: {"scope_note": str, "categories": [{"name": str, "what": str, "value": 1-5, "specs": ["v1", "v38.5", ...]}],
                "observations": [str], "follow_ups": [str]}
Exit 0 on success; exit 1 and nothing written if a spec is unlisted, listed twice or has no file; exit 2 on unreadable input.
Prints `kept values:` and `proposed values:` lines to stderr for the run report."""
import argparse, json, os, re, sys

def spec_files(d):
    out = {}
    for sub, done in ((d, False), (os.path.join(d, 'completed'), True)):
        if os.path.isdir(sub):
            for f in os.listdir(sub):
                m = re.match(r'^spec-v(\d+(?:\.\d+)?)-.*\.md$', f)
                if m:
                    out['v' + m.group(1)] = done
    return out

def old_values(path):
    vals, hdr = {}, None
    try:
        lines = [ln for ln in open(path, encoding='utf-8').read().splitlines() if ln.startswith('|')]
    except OSError:
        return vals
    for ln in lines:
        cells = [c.strip() for c in ln.strip().strip('|').split('|')]
        low = [c.lower() for c in cells]
        if hdr is None:
            if 'value' in low and 'category' in low:
                hdr = (low.index('category'), low.index('value'))
            continue
        if set(''.join(cells)) <= set('-: '):
            continue
        try:
            vals[cells[hdr[0]]] = cells[hdr[1]]
        except IndexError:
            pass
    return vals

def num(v):
    return float(v[1:])

def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--grouping', required=True)
    ap.add_argument('--specs-dir', default='specs')
    ap.add_argument('--out', default=os.path.join('specs', 'spec-categories.md'))
    ap.add_argument('--date', default='')
    ap.add_argument('--dry-run', action='store_true')
    a = ap.parse_args(argv)
    try:
        g = json.load(open(a.grouping, encoding='utf-8'))
        cats = g['categories']
    except (OSError, ValueError, KeyError) as e:
        print(f'ERROR: cannot read grouping {a.grouping}: {e}', file=sys.stderr)
        return 2
    files = spec_files(a.specs_dir)
    seen, problems = {}, []
    for c in cats:
        for v in c['specs']:
            v = v.rstrip('*')
            if v in seen:
                problems.append(f'{v} listed twice ({seen[v]} and {c["name"]})')
            seen[v] = c['name']
            if v not in files:
                problems.append(f'{v} has no spec file')
    problems += [f'{v} is in no category' for v in sorted(files, key=num) if v not in seen]
    if problems:
        print('REFUSING to write:\n  ' + '\n  '.join(problems), file=sys.stderr)
        return 1
    old = old_values(a.out)
    done_n = sum(files.values())
    L = ['# Spec Categories', '',
         f'Product-manager view of all {len(files)} specs: {done_n} completed (marked `*`) and {len(files) - done_n} not yet complete,'
         f' as of {a.date or "today"}.',
         g.get('scope_note', ''),
         'A new category keeps the Value proposed in the analysis; an existing category keeps the Value already in this file.', '',
         '## Categories', '', "| Category | What it's for | Specs | Count | Value |", '| --- | --- | --- | --- | --- |']
    kept, proposed = [], []
    for c in cats:
        vers = sorted((v.rstrip('*') for v in c['specs']), key=num)
        toks = [v + ('*' if files[v] else '') for v in vers]
        if c['name'] in old:
            val = old[c['name']]; kept.append((c['name'], val))
        else:
            val = str(c['value']); proposed.append((c['name'], val))
        L.append(f'| {c["name"]} | {c["what"]} | {", ".join(toks)} | {len(toks)} | {val} |')
    L += ['', "Value (1-5) is the weight `/sdd-spec-loop --priority roi` uses for every spec in the category. A spec's own `value:`",
          'frontmatter overrides it; a spec in no category scores 3. Edit the Value column to change priorities. A trailing `*` marks a',
          'completed spec. Parsed by `modules/sdd/scripts/spec-loop-queue.py` (table with `Specs` and `Value` columns).', '',
          '## Observations', ''] + [f'- {b}' for b in g.get('observations', [])] + \
         ['', '## Open follow-ups', ''] + [f'- {b}' for b in g.get('follow_ups', [])] + ['']
    text = '\n'.join(L)
    if a.dry_run:
        print(text)
    else:
        open(a.out, 'w', encoding='utf-8').write(text)
    print(f'kept values: {kept}', file=sys.stderr)
    print(f'proposed values: {proposed}', file=sys.stderr)
    return 0

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
