#!/usr/bin/env python3
"""spec-digest.py — one compact block per spec (version, completed?, title, tags, Why statement) for category analysis (spec v139).
Usage: spec-digest.py [--specs-dir specs] [--why-chars 330]. Read-only; prints to stdout."""
import argparse, os, re

def block(path, why_chars):
    txt = open(path, encoding='utf-8').read()
    fm = {}
    m = re.match(r'^---\n(.*?)\n---\n', txt, re.S)
    if m:
        for ln in m.group(1).splitlines():
            k, _, v = ln.partition(':')
            fm[k.strip()] = v.strip().strip('"')
    body = txt[m.end():] if m else txt
    why = re.search(r'>\s*(.+?)(?:\n\n|\n---|\n###)', body, re.S)
    why = re.sub(r'\s+', ' ', why.group(1)).strip() if why else ''
    return fm, why[:why_chars]

ap = argparse.ArgumentParser()
ap.add_argument('--specs-dir', default='specs')
ap.add_argument('--why-chars', type=int, default=330)
a = ap.parse_args()
rows = []
for d, done in ((a.specs_dir, False), (os.path.join(a.specs_dir, 'completed'), True)):
    if not os.path.isdir(d):
        continue
    for f in os.listdir(d):
        m = re.match(r'^spec-v(\d+(?:\.\d+)?)-.*\.md$', f)
        if m:
            rows.append((float(m.group(1)), 'v' + m.group(1), done, os.path.join(d, f)))
for _, v, done, path in sorted(rows):
    fm, why = block(path, a.why_chars)
    print(f"{v}{'*' if done else ''} | {fm.get('display_name') or fm.get('name', '')} | tags: {fm.get('tags', '')} | {why}")
