# gchat Module — Google Chat for aidev toolkit

The `/gchat` skill: list your Chat spaces, read message history, and post messages as yourself. Also provides a notifier so [backbone](../backbone/README.md) can ping a Chat space.

## Layout

| Dir | Holds | Installed to |
| --- | ----- | ------------ |
| `scripts/` | `gchat.sh` (wrapper), `auth.py`, `list_spaces.py`, `read_messages.py`, `send.py`, `download_attachments.py`, `gchat-notify.sh` (backbone notifier) | stays in place; called as `~/.claude/aidev-toolkit/modules/gchat/scripts/<script>` |
| `skills/` | `/gchat` | `~/.claude/commands/` and `~/.claude/skills/` by `scripts/install.sh` (`GCHAT_SKILLS`) |

## What is not here

Credentials and tokens. They are per person, in `~/.config/aidev/gchat/` (`GCHAT_CONFIG_DIR` overrides): `credentials.json`, `token.json`, and an optional `config`. Nothing is stored in a project or in the toolkit checkout.

## Setup (once per person)

1. `/aid-update` installs the module.
2. In a Google Cloud project, enable the **Google Chat API** (APIs & Services → Library).
3. Create a **Desktop app** OAuth client and save its JSON as `~/.config/aidev/gchat/credentials.json`.
4. Run the auth step yourself, because it opens a browser: `! ~/.claude/aidev-toolkit/modules/gchat/scripts/gchat.sh auth`
5. Sign in with your own Google account and grant consent. The token refreshes itself afterwards.

Dependencies: `uv` (fetches them on demand) or `python3` with `google-api-python-client` and `google-auth-oauthlib`.

If consent fails with an admin-policy or disabled-client error, a Workspace administrator has to allowlist the client and the Chat scopes. It is not a code bug and there is no workaround.

## Scopes

`chat.spaces.readonly` (list), `chat.messages.readonly` (read), `chat.messages.create` (post as you). The module cannot manage memberships or edit or delete messages. After scopes change, re-run `auth` once.

## Send confirmation

Google Chat has no drafts: a send is live immediately. By default `/gchat send` shows the space and exact text and waits for approval.

```bash
gchat.sh confirm        # print the mode: ask (default) or auto
gchat.sh confirm auto   # send without asking
gchat.sh confirm ask    # ask again
```

Stored as `confirm=` in `~/.config/aidev/gchat/config`. An invalid stored value is an error, never a silent `auto`.

## Backbone notifier

In `backbone.config` (machine-local, in the agent-backbone repo — never in a committed project file, because it names a command to run):

```text
notify_command=~/.claude/aidev-toolkit/modules/gchat/scripts/gchat-notify.sh
```

Roster notify targets must be space resource names (`spaces/AAAAAAAAAAA`, from `/gchat list`). `gchat-notify.sh` validates the target before sending. Whether a ping asks first is backbone's `notify_confirm`, separate from `confirm` above.

## Tests

`tests/test-gchat.sh` covers the wrapper, the `confirm` setting, notifier validation and the backbone-notify integration (real scripts, no mocks). Live Chat calls need a real OAuth token and are not exercised.
