#!/usr/bin/env python3
"""spec-loop-budget.py — token/dollar meter for /sdd-spec-loop (spec v137, AC-5).

Sources (see docs/spec-loop-token-spend.md):
  --transcript FILE   a Claude Code session transcript (.jsonl): usage deduped by message.id (last line wins);
                      exact dollars from the last `cost-state` line when present.
  --result FILE       a headless `claude -p --output-format json` result (repeatable): usage and total_cost_usd.

Subcommands:
  reading  SOURCE...                  print a JSON reading (cumulative totals).
  delta    BEFORE.json SOURCE...      spend since a saved reading (one pass, or the run so far).
  check    --since R.json SOURCE... [--budget-tokens N] [--budget-usd N]
                                      print the delta; exit 3 when a budget is reached.

"tokens" counts new work: input + cache_creation + output. Cache reads are reported separately (they are cheap and
would swamp the figure). Dollars: `usd_exact` when the source carries it, else `usd_estimated` from the price table
(modules/sdd/templates/spec-loop-prices.json), else null (unknown — never 0).

Exit codes: 0 ok, 2 malformed/unreadable input (error names the file and line) or a --budget-usd that cannot be enforced
(dollars unknown), 3 budget reached.
Set SPEC_LOOP_RUN_ID to tag every log line with the run id.
A malformed line is an error, not zero spend.
"""
import argparse, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
PRICES = os.path.join(HERE, '..', 'templates', 'spec-loop-prices.json')
KINDS = ('input', 'cache_creation', 'cache_read', 'output')


class MeterError(Exception):
    pass


def log(step, outcome, **kw):
    extra = ' '.join(f'{k}={v}' for k, v in kw.items())
    run = os.environ.get('SPEC_LOOP_RUN_ID', '-')
    print(f'spec-loop-budget run={run} step={step} outcome={outcome} {extra}'.rstrip(), file=sys.stderr)


def blank():
    return {'tokens': {k: 0 for k in KINDS}, 'by_model': {}, 'usd_exact': None}


def add_usage(r, model, u):
    for k, src in (('input', 'input_tokens'), ('cache_creation', 'cache_creation_input_tokens'),
                   ('cache_read', 'cache_read_input_tokens'), ('output', 'output_tokens')):
        v = u.get(src, 0) or 0
        if not isinstance(v, (int, float)):
            raise MeterError(f'non-numeric {src}: {v!r}')
        r['tokens'][k] += int(v)
        bm = r['by_model'].setdefault(model or 'unknown', {kk: 0 for kk in KINDS})
        bm[k] += int(v)


def read_transcript(path):
    r = blank()
    by_id, order = {}, 0
    try:
        fh = open(path, encoding='utf-8')
    except OSError as e:
        raise MeterError(f'cannot read {path}: {e}')
    with fh:
        for n, line in enumerate(fh, 1):
            if not line.strip():
                continue
            try:
                d = json.loads(line)
            except json.JSONDecodeError as e:
                raise MeterError(f'{path}:{n}: malformed JSON line ({e.msg})')
            if not isinstance(d, dict):
                raise MeterError(f'{path}:{n}: line is not a JSON object')
            if d.get('type') == 'cost-state' and isinstance(d.get('totalCostUSD'), (int, float)):
                r['usd_exact'] = float(d['totalCostUSD'])
            m = d.get('message')
            if isinstance(m, dict) and isinstance(m.get('usage'), dict):
                key = m.get('id') or f'_line{n}'
                by_id[key] = (m.get('model'), m['usage'])
    for model, u in by_id.values():
        add_usage(r, model, u)
    return r


def read_result(path):
    r = blank()
    try:
        d = json.load(open(path, encoding='utf-8'))
    except OSError as e:
        raise MeterError(f'cannot read {path}: {e}')
    except json.JSONDecodeError as e:
        raise MeterError(f'{path}: malformed JSON ({e.msg})')
    if not isinstance(d, dict) or not isinstance(d.get('usage'), dict):
        raise MeterError(f'{path}: not a headless result (no usage object)')
    models = list((d.get('modelUsage') or {}).keys())
    add_usage(r, models[0] if len(models) == 1 else 'unknown', d['usage'])
    if isinstance(d.get('total_cost_usd'), (int, float)):
        r['usd_exact'] = float(d['total_cost_usd'])
    return r


def merge(a, b):
    for k in KINDS:
        a['tokens'][k] += b['tokens'][k]
    for m, t in b['by_model'].items():
        bm = a['by_model'].setdefault(m, {k: 0 for k in KINDS})
        for k in KINDS:
            bm[k] += t[k]
    if b['usd_exact'] is not None:
        a['usd_exact'] = (a['usd_exact'] or 0.0) + b['usd_exact']


def load_prices():
    try:
        return json.load(open(PRICES, encoding='utf-8'))
    except (OSError, json.JSONDecodeError) as e:
        log('prices', 'unavailable', error=e)
        return {}


def estimate(by_model, prices):
    """Estimated USD, or None if any model with spend has no price entry."""
    total = 0.0
    for model, t in by_model.items():
        if not any(t.values()):
            continue
        name = model.split('anthropic.')[-1]
        p = prices.get(name)
        if not isinstance(p, dict):
            return None
        total += (t['input'] * p['input'] + t['output'] * p['output'] +
                  t['cache_creation'] * p['cache_write'] + t['cache_read'] * p['cache_read']) / 1e6
    return round(total, 6)


def finish(r):
    t = r['tokens']
    r['tokens_new'] = t['input'] + t['cache_creation'] + t['output']
    r['usd_estimated'] = estimate(r['by_model'], load_prices())
    return r


def reading(sources_t, sources_r):
    r = blank()
    for p in sources_t:
        merge(r, read_transcript(p))
    for p in sources_r:
        merge(r, read_result(p))
    return finish(r)


def diff(after, before):
    d = blank()
    for k in KINDS:
        d['tokens'][k] = after['tokens'][k] - before['tokens'][k]
    for m, t in after['by_model'].items():
        b = before['by_model'].get(m, {k: 0 for k in KINDS})
        d['by_model'][m] = {k: t[k] - b[k] for k in KINDS}
    if after['usd_exact'] is not None:
        d['usd_exact'] = round(after['usd_exact'] - (before['usd_exact'] or 0.0), 6)
    return finish(d)


def load_reading(path):
    try:
        r = json.load(open(path, encoding='utf-8'))
        assert isinstance(r['tokens'], dict) and isinstance(r['by_model'], dict)
        return r
    except (OSError, ValueError, KeyError, AssertionError) as e:
        raise MeterError(f'{path}: not a reading ({e})')


def dollars(r):
    return r['usd_exact'] if r['usd_exact'] is not None else r['usd_estimated']


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('cmd', choices=['reading', 'delta', 'check'])
    ap.add_argument('args', nargs='*', help='delta: BEFORE.json first')
    ap.add_argument('--transcript', action='append', default=[])
    ap.add_argument('--result', action='append', default=[])
    ap.add_argument('--since')
    ap.add_argument('--budget-tokens', type=int)
    ap.add_argument('--budget-usd', type=float)
    a = ap.parse_args(argv)
    try:
        if a.cmd == 'reading':
            out = reading(a.transcript, a.result)
        else:
            since = a.since or (a.args[0] if a.cmd == 'delta' and a.args else None)
            if not since:
                raise MeterError(f'{a.cmd} needs a BEFORE reading (--since FILE)')
            out = diff(reading(a.transcript, a.result), load_reading(since))
    except MeterError as e:
        log(a.cmd, 'error', error=e)
        print(f'ERROR: {e}', file=sys.stderr)
        return 2
    reasons = []
    if a.cmd == 'check':
        if a.budget_tokens is not None and out['tokens_new'] >= a.budget_tokens:
            reasons.append(f'tokens {out["tokens_new"]} >= {a.budget_tokens}')
        if a.budget_usd is not None:
            usd = dollars(out)
            if usd is None:
                # Unknown dollars must not look like "under budget": a dollar-only budget would never stop.
                msg = 'dollars unknown for this model (no exact cost, no price entry); cannot enforce --budget-usd'
                log('check', 'error', error=msg)
                print(f'ERROR: {msg}. Use --budget-tokens or add the model to spec-loop-prices.json', file=sys.stderr)
                return 2
            elif usd >= a.budget_usd:
                reasons.append(f'usd {usd} >= {a.budget_usd}')
        out['budget_reached'] = reasons
    log(a.cmd, 'ok', tokens_new=out['tokens_new'], usd=dollars(out))
    print(json.dumps(out, indent=2))
    return 3 if reasons else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
