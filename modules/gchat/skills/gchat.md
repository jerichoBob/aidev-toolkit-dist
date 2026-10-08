---
name: gchat
tier: extended
description: "/gchat — Google Chat access: list spaces, read message history, send a message"
argument-hint: "[list | read | send <space> / <text> | confirm [ask|auto] | setup]"
allowed-tools: Read, AskUserQuestion, Bash(~/.claude/aidev-toolkit/modules/gchat/scripts/*:*), Bash(bash:*), Bash(mkdir:*), Bash(date:*)
---

# /gchat — Google Chat

Google Chat access for whichever Google account the current user authenticates as. Each person runs their own OAuth consent; credentials and token live per user in `~/.config/aidev/gchat/` (override with `GCHAT_CONFIG_DIR`) — never in a project or in the toolkit.

**Google Chat has no drafts.** `send` posts immediately and visibly to everyone in the space. By default (`confirm=ask`) show the user the exact space (display name, not just the ID) and the exact message text, and get explicit confirmation with `AskUserQuestion` before every send — every time, not just once. The user can opt out with `gchat.sh confirm auto` (see `/gchat confirm`); never switch it yourself.

Scopes: `chat.spaces.readonly` (list), `chat.messages.readonly` (read), `chat.messages.create` (post as the user). This skill cannot manage memberships or edit/delete anything.

```bash
GCHAT=~/.claude/aidev-toolkit/modules/gchat/scripts/gchat.sh
```

`gchat.sh` runs the Python scripts through `uv` (dependencies fetched on demand) or, without `uv`, `python3` with `google-api-python-client` and `google-auth-oauthlib` installed.

## `/gchat setup` — one-time, per person

1. In a Google Cloud project, enable the **Google Chat API** (APIs & Services → Library) and create a **Desktop app** OAuth client. Save its JSON as `~/.config/aidev/gchat/credentials.json`.
2. Run the auth step yourself — it opens a browser Claude cannot drive, so tell the user to type `! ~/.claude/aidev-toolkit/modules/gchat/scripts/gchat.sh auth`.
3. Sign in with your own Google account and grant consent. The token is cached at `~/.config/aidev/gchat/token.json` and auto-refreshes.

If consent fails with an admin-policy / disabled-client error, it is not a code bug — report it as **blocked** and route to the Workspace administrator to allowlist the client and Chat scopes. Do not build a workaround.

## `/gchat list`

```bash
bash "$GCHAT" list_spaces
```

Prints `resource-name<TAB>type<TAB>display-name`. Use the resource name (`spaces/AAAAAAAAAAA`) as `--space` elsewhere. To keep the list: `mkdir -p .claude/data/gchat && bash "$GCHAT" list_spaces --json .claude/data/gchat/spaces-$(date +%Y%m%d).json` (`--json` output must stay under `.claude/data/`).

## `/gchat read`

Read-only.

```bash
bash "$GCHAT" read_messages --space spaces/AAAAAAAAAAA --days 3        # one space or DM
bash "$GCHAT" read_messages --scan --days 2 --grep "invoice|deploy"     # every space, regex-filtered
```

Add `--json .claude/data/gchat/messages-<date>.json` to keep the output. Attachments uploaded directly in Chat can be fetched with `bash "$GCHAT" download_attachments --from-json <that file>` (lands in `.claude/data/gchat/attachments/`, never overwritten). Files shared from Drive are reported with their Drive ID and skipped. After scopes change, re-run `auth` once.

## `/gchat confirm [ask|auto]`

`bash "$GCHAT" confirm` prints the current mode; `bash "$GCHAT" confirm auto` or `... confirm ask` sets it (stored as `confirm=` in `~/.config/aidev/gchat/config`, default `ask`). Only change it when the user explicitly asks. Backbone pings are governed separately by `notify_confirm` in `backbone.config`.

## `/gchat send <space> / <text>`

0. Run `bash "$GCHAT" confirm`. If it prints `ask` (or errors), do steps 1–3. If `auto`, resolve the space (step 1), then send (step 3) and report the space and text sent afterwards.
1. Resolve `<space>` to a resource name (`list` if needed) and its display name.
2. (`ask` mode) Show both the display name and the exact text; ask for confirmation with `AskUserQuestion`.
3. Only on approval (or in `auto` mode): `bash "$GCHAT" send --space spaces/AAAAAAAAAAA --text "..."`

## Backbone notifications

To have backbone ping a Chat space when a message goes unacknowledged, set in `backbone.config` (machine-local, in the agent-backbone repo — not in a project's `.aid/config.yaml`, because that file is committed and a notifier command must never come from a repo):

```text
notify_command=~/.claude/aidev-toolkit/modules/gchat/scripts/gchat-notify.sh
```

and make the roster `notify` target for each agent a space resource name (`spaces/AAAAAAAAAAA`). Backbone's `notify_confirm` (default `ask`) governs approval before each ping.

## What this skill does NOT do

- Search past messages server-side (`read_messages` fetches a time window and filters locally).
- Manage membership, create or archive spaces, or edit/delete sent messages.
- Send anything the user has not approved — either per send (`ask`) or by opting into `auto`.
