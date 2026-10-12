export type Item = {
  path: string
  kind: 'file' | 'dir' | 'link' | 'missing'
  size: number
  entries: number
  /** pending: waiting for the user. trashed: moved to ~/.Trash by the user's click. kept: the user chose to keep it. failed: the move did not work. */
  status: 'pending' | 'trashed' | 'kept' | 'failed'
  note?: string
}

declare module 'claude-code' {
  interface PluginState {
    'rm-review': { items: Item[] }
  }
}
