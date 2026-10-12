# rm-review

A Claude Code mod that works with the [destructive-command guard](../../docs/destructive-command-guard.md). When Claude tries an `rm`, the command is blocked and the files it would have removed appear in a side panel. Each file has three buttons:

- **Move to Trash** moves it into `~/.Trash`, so you can undo it. There is also a **Move all** button when several are waiting.
- **Reveal** shows it in Finder.
- **Keep** dismisses it.

Claude never deletes anything. You decide, one click at a time.

## Requirements

- The destructive-command guard installed (`scripts/install.sh` does this). The mod asks the guard's script what an `rm` would remove, so there is one detector, not two.
- macOS. Trash and Reveal use `~/.Trash` and `open -R`.

## Try it

From a Claude Code session in a terminal, run Claude Code with the mod folder:

```bash
claude --plugin-dir ~/.claude/aidev-toolkit/modules/rm-review
```

`/rm-review` reopens the panel at any time.

## Files

| Path | What it does |
| ---- | ------------ |
| `hooks/register.tsx` | the hooks: blocks `rm`, fills the panel, handles the buttons |
| `hooks/lib.ts` | pure logic (which paths may be trashed, list merging, Trash names, messages) |
| `hooks/lib.test.ts` | tests for `lib.ts`; run `claude plugin test modules/rm-review` |
| `types/index.d.ts` | the shape of the panel's state |

## Safety

- The Trash button refuses your home folder, any folder above it, and system locations such as `/System`, `/usr`, `/etc`, and `/Applications`.
- A move never overwrites: if the name is taken in the Trash, a timestamp is added.
- Moves run as an argument list with no shell, so a file name is never parsed as a command.
