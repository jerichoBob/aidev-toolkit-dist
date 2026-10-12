// Pure logic, real values, no mocks.
import { expect, test } from 'claude-code/testing'

import { denyMessage, describe, humanSize, isTrashable, mergeItems, setStatus, trashTarget } from './lib'
import type { Item } from '../types'

const HOME = '/Users/bob'

test('isTrashable refuses home, its ancestors, system paths, traversal and relative paths', () => {
  for (const bad of ['/', '/Users', HOME, HOME + '/', '/System/Library', '/usr/bin/ls', '/etc/hosts', '/tmp', '/dev/null', '/Applications/X.app', 'relative/x', HOME + '/a/../../b', '']) {
    expect(isTrashable(bad, HOME)).toBe(false)
  }
})

test('isTrashable allows ordinary files and folders', () => {
  for (const ok of [HOME + '/Play/x.txt', HOME + '/Play/proj/build', '/tmp/demo/a.tmp', '/private/tmp/x', '/Volumes/Data/old']) {
    expect(isTrashable(ok, HOME)).toBe(true)
  }
})

test('mergeItems adds new paths, keeps old statuses, marks missing ones', () => {
  const first = mergeItems([], [
    { path: '/a', kind: 'file', size: 3, items: 0 },
    { path: '/gone', kind: 'missing', size: 0, items: 0 },
  ])
  expect(first.map(i => [i.path, i.status])).toEqual([['/a', 'pending'], ['/gone', 'kept']])
  const trashed = setStatus(first, '/a', 'trashed', 'x')
  const again = mergeItems(trashed, [{ path: '/a', kind: 'file', size: 3, items: 0 }, { path: '/b', kind: 'dir', size: 0, items: 4 }])
  expect(again.map(i => [i.path, i.status])).toEqual([['/a', 'trashed'], ['/gone', 'kept'], ['/b', 'pending']])
})

test('trashTarget keeps the name unless taken', () => {
  expect(trashTarget('/h/.Trash', '/x/y/file.txt', () => false, 0)).toBe('/h/.Trash/file.txt')
  expect(trashTarget('/h/.Trash/', '/x/y/dir/', () => true, 99)).toBe('/h/.Trash/dir.99')
})

test('describe and humanSize read well', () => {
  expect(humanSize(10)).toBe('10 B')
  expect(humanSize(2048)).toBe('2.0 KB')
  expect(describe({ kind: 'dir', size: 0, entries: 1000 })).toBe('folder, 1000+ entries')
  expect(describe({ kind: 'file', size: 2048, entries: 0 })).toBe('file, 2.0 KB')
})

test('denyMessage says nothing was removed and points at the panel', () => {
  const m = denyMessage([{ path: '/a', kind: 'file', size: 1, items: 0 }], ['rm with --force / -f'])
  expect(m).toContain('Nothing was removed')
  expect(m).toContain('rm with --force / -f')
  expect(m).toContain('1 item(s)')
})

test('items typed as the state contract', () => {
  const i: Item = { path: '/a', kind: 'file', size: 1, entries: 0, status: 'pending' }
  expect(i.status).toBe('pending')
})
