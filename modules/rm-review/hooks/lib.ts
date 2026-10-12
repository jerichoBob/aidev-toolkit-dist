// Pure logic for rm-review: no engine calls, so it is tested directly (lib.test.ts).
import type { Item } from '../types'

export type AnalyzedFile = { path: string; kind: Item['kind']; size: number; items: number }

/** Paths the Trash button refuses outright, whatever the analysis said. */
const SYSTEM_PREFIXES = ['/System', '/bin', '/sbin', '/usr', '/etc', '/var/db', '/Library', '/Applications', '/dev', '/cores', '/private/etc']

export function isTrashable(path: string, home: string): boolean {
  if (!path.startsWith('/') || path.includes('\0')) return false
  if (path.split('/').includes('..')) return false
  const clean = path.replace(/\/+$/, '')
  const h = home.replace(/\/+$/, '')
  if (clean === '' || clean === h) return false
  if (h.startsWith(clean + '/')) return false // an ancestor of the home folder
  if (clean === '/Users' || clean === '/private' || clean === '/tmp' || clean === '/var' || clean === '/Volumes') return false
  return !SYSTEM_PREFIXES.some(p => clean === p || clean.startsWith(p + '/'))
}

/** Add analyzed files that are not listed yet; a file already listed keeps its status. */
export function mergeItems(list: Item[], files: AnalyzedFile[]): Item[] {
  const known = new Set(list.map(i => i.path))
  const added: Item[] = []
  for (const f of files) {
    if (known.has(f.path)) continue
    known.add(f.path)
    added.push({
      path: f.path,
      kind: f.kind,
      size: f.size,
      entries: f.items,
      status: f.kind === 'missing' ? 'kept' : 'pending',
      note: f.kind === 'missing' ? 'does not exist' : undefined,
    })
  }
  return [...list, ...added].slice(-200)
}

export function setStatus(list: Item[], path: string, status: Item['status'], note?: string): Item[] {
  return list.map(i => (i.path === path ? { ...i, status, note } : i))
}

/** Where a file goes in the Trash: its own name, or with a suffix when that name is taken. */
export function trashTarget(trashDir: string, path: string, isTaken: (candidate: string) => boolean, stamp: number): string {
  const name = path.replace(/\/+$/, '').split('/').pop() || 'item'
  const dir = trashDir.replace(/\/+$/, '')
  const first = `${dir}/${name}`
  return isTaken(first) ? `${first}.${stamp}` : first
}

export function humanSize(n: number): string {
  if (n < 1024) return `${n} B`
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`
  if (n < 1024 * 1024 * 1024) return `${(n / 1024 / 1024).toFixed(1)} MB`
  return `${(n / 1024 / 1024 / 1024).toFixed(1)} GB`
}

export function describe(i: Pick<Item, 'kind' | 'size' | 'entries'>): string {
  if (i.kind === 'dir') return `folder, ${i.entries}${i.entries >= 1000 ? '+' : ''} entries`
  if (i.kind === 'missing') return 'not there'
  return `${i.kind}, ${humanSize(i.size)}`
}

export function denyMessage(files: AnalyzedFile[], reasons: string[]): string {
  const existing = files.filter(f => f.kind !== 'missing')
  return [
    'rm-review: rm is blocked here. Nothing was removed.',
    reasons.length ? `Why: ${reasons.join('; ')}.` : '',
    existing.length
      ? `${existing.length} item(s) are listed in the rm review panel for the user to move to the Trash if they agree.`
      : 'None of the named paths exist.',
    'Do not retry with another spelling. Tell the user what should go and why.',
  ]
    .filter(Boolean)
    .join('\n')
}
