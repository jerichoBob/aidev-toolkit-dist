import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Item } from '../types'
import { denyMessage, describe, isTrashable, mergeItems, setStatus, trashTarget } from './lib'
import type { AnalyzedFile } from './lib'

// When Claude tries an rm, this blocks it and lists what it would have removed in a side panel.
// Claude never deletes: the user presses "Move to Trash" (a move into ~/.Trash, so it can be undone).
// The analysis comes from the global hook script, so there is one detector, not two.

const PANE = 'rm-review'
const items = atom({ plugin: 'rm-review', key: 'items' } as const, [])

type Analysis = {
  blocked: boolean
  reasons: string[]
  rm: null | { files: AnalyzedFile[] }
}

let home: string | undefined

async function getHome($: EngineInterface): Promise<string> {
  if (home === undefined) {
    const r = await $.process.run(['/bin/sh', '-c', 'printf %s "$HOME"'])
    home = String(r.stdout).trim()
  }
  return home
}

async function analyze($: EngineInterface, command: string): Promise<Analysis | undefined> {
  const script = `${await getHome($)}/.claude/aidev-toolkit/scripts/guard-destructive-commands.py`
  const cwd = await $.session.cwd()
  const r = await $.process.run(['/usr/bin/env', 'python3', '-I', script, '--analyze'], {
    stdin: JSON.stringify({ tool_input: { command }, cwd }),
    timeoutMs: 10000,
  })
  if (r.exitCode !== 0) return undefined
  try {
    return JSON.parse(r.stdout) as Analysis
  } catch {
    return undefined
  }
}

async function moveToTrash($: EngineInterface, path: string): Promise<void> {
  const h = await getHome($)
  if (!isTrashable(path, h)) {
    await update($, items, list => setStatus(list, path, 'failed', 'refused: protected location'))
    return
  }
  const trashDir = `${h}/.Trash`
  const first = trashTarget(trashDir, path, () => false, 0)
  const target = (await $.fs.exists(first)) ? trashTarget(trashDir, path, () => true, Date.now()) : first
  // -n: never overwrite. Argument vector, no shell: the path is never parsed as syntax.
  const r = await $.process.run(['/bin/mv', '-n', '--', path, target])
  const isGone = !(await $.fs.exists(path))
  await update($, items, list =>
    isGone && r.exitCode === 0
      ? setStatus(list, path, 'trashed', `in ~/.Trash as ${target.split('/').pop()}`)
      : setStatus(list, path, 'failed', String(r.stderr).trim().slice(0, 120) || 'move failed'),
  )
}

async function moveAllToTrash($: EngineInterface, paths: string[]): Promise<void> {
  for (const p of paths) await moveToTrash($, p)
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'rm-review', description: 'Open the panel listing files Claude tried to rm' })
    return next(e)
  })

  on('command.run', { command: 'rm-review' }, async $ => {
    await $.ui.open({ id: PANE, title: 'rm review' })
    return { text: 'rm review panel opened.' }
  })

  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    if (!/\b(rm|unlink|rmdir)\b/.test(e.command)) return next(e) // cheap pre-filter
    const analysis = await analyze($, e.command)
    if (!analysis || !analysis.rm) return next(e)

    const files = analysis.rm.files
    await update($, items, list => mergeItems(list, files))
    void $.ui.open({ id: PANE, title: 'rm review' })
    $.ui.toast(`rm blocked: ${files.filter(f => f.kind !== 'missing').length} item(s) in the rm review panel`)

    return { deny: denyMessage(files, analysis.reasons) }
  }).catch(($, e, next) =>
    // If this guard itself fails: block only what looks like a delete; the global hook still guards the rest.
    next.called || !/\b(rm|unlink|rmdir)\b/.test(e.command)
      ? next(e)
      : { deny: 'rm-review: its check failed on a command that looks like a delete. Nothing was run.' },
  )

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Button } = $.ui.resolve(e)
    const list = await read($, items)
    const pending = list.filter((i: Item) => i.status === 'pending')
    const room = Math.max(3, (e.viewport?.rows ?? 24) - 8)

    return (
      <Box flexDirection="column">
        <Text>
          {pending.length === 0 ? 'Nothing waiting.' : `${pending.length} waiting for you.`} Claude cannot delete; you decide.
        </Text>
        {pending.length > 1 && (
          <Button
            key="trash-all"
            variant="primary"
            onPress={() =>
              moveAllToTrash(
                $,
                pending.map((i: Item) => i.path),
              )
            }
          >
            Move all {pending.length} to Trash
          </Button>
        )}
        {list.length === 0 && <Text dimColor>No rm attempts yet.</Text>}
        {list.slice(-room).map((i: Item) => (
          <Box key={i.path} flexDirection="column" marginTop={1}>
            <Text dimColor={i.status !== 'pending'}>
              {i.status === 'trashed' ? 'trashed ' : i.status === 'kept' ? 'kept ' : i.status === 'failed' ? 'FAILED ' : ''}
              {i.path}
            </Text>
            <Text dimColor>
              {describe(i)}
              {i.note ? ` - ${i.note}` : ''}
            </Text>
            {i.status === 'pending' && (
              <Box>
                <Button key={`t-${i.path}`} onPress={() => moveToTrash($, i.path)}>
                  Move to Trash
                </Button>
                <Button key={`r-${i.path}`} plain onPress={() => $.process.run(['/usr/bin/open', '-R', i.path])}>
                  Reveal
                </Button>
                <Button key={`k-${i.path}`} plain onPress={() => update($, items, l => setStatus(l, i.path, 'kept'))}>
                  Keep
                </Button>
              </Box>
            )}
          </Box>
        ))}
        {list.length > 0 && (
          <Button key="clear" plain onPress={() => update($, items, l => l.filter((i: Item) => i.status === 'pending'))}>
            Clear finished
          </Button>
        )}
      </Box>
    )
  })
}
