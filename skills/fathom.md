---
name: fathom
tier: extended
description: Browse, search, and read transcripts from your Fathom meeting recordings.
argument-hint: "[list|date|today|external|search|view|transcript|summary|help] [options]"
allowed-tools: Bash(~/.claude/aidev-toolkit/scripts/fathom-api.sh:*), Bash(date:*)
model: inherit
---

# Fathom Recording Explorer

Explore and analyze Fathom meeting recordings.

## When to Use

- User asks to list, search, or review Fathom meeting recordings
- User wants a meeting transcript or AI summary of a past call

## Access Check

First, verify the API key is configured:

```bash
~/.claude/aidev-toolkit/scripts/fathom-api.sh check
```

If this does not print `ok`, output:

```text
Fathom API key not found.

Set it up:
  mkdir -p ~/.config/fathom
  echo 'FATHOM_API_KEY=your-key-here' > ~/.config/fathom/config
  chmod 600 ~/.config/fathom/config

Get a key from your Fathom account settings (https://fathom.video), then re-run /fathom.
```

Then STOP. Do not proceed with any other instructions.

## Arguments

Check `$ARGUMENTS` to determine which command to run:

| Argument | Description |
|----------|--------------|
| (empty) | Show help |
| `list` | List recent meetings (default 10) |
| `list --limit N` | List N recent meetings |
| `date <YYYY-MM-DD>` | List all meetings on a specific date |
| `today` | List today's meetings only |
| `external` | List meetings with external participants |
| `search <query>` | Search meetings by title |
| `view <id>` | View meeting details |
| `transcript <id>` | Get full transcript |
| `summary <id>` | AI summary of transcript |
| `help` | Show help |

## Instructions

All API calls go through `~/.claude/aidev-toolkit/scripts/fathom-api.sh <endpoint> <jq-filter> [jq-args...]`. Never call the Fathom API directly with `curl` — the script is the only thing that reads the API key.

### Help (`help`)

If argument is `help` (or empty), output this help text:

```text
/fathom - Fathom Recording Explorer
===================================

Usage: /fathom <command> [options]

Commands:
  list [--limit N]     List recent meetings (default: 10)
  date <YYYY-MM-DD>    List all meetings on a specific date
  today                Today's meetings
  external             List meetings with external participants
  search <query>       Search meetings by title
  view <id>            View meeting details and participants
  transcript <id>      Get full meeting transcript
  summary <id>         AI-generated summary of meeting
  help                 Show this help

Examples:
  /fathom                      Show this help
  /fathom list                 List recent meetings
  /fathom date 2026-02-05      Meetings from Feb 5
  /fathom today                Today's meetings
  /fathom search "caliber"     Find meetings about Caliber
  /fathom view 119440202       View meeting details
  /fathom transcript 119440202 Get transcript
  /fathom summary 119440202    Summarize meeting

API: https://developers.fathom.ai
```

### List Meetings (`list`)

```bash
~/.claude/aidev-toolkit/scripts/fathom-api.sh "meetings?limit=10" \
  '.items | map({title, recording_id, recording_start_time, recording_end_time, recorded_by: .recorded_by.name, external: (.calendar_invitees_domains_type == "one_or_more_external")})'
```

Honor `--limit N` by substituting `limit=N` in the endpoint.

Display as a formatted table with: Date, Title (truncate to 40 chars), Duration, Recorded By, External? (Yes/No), Recording ID. Include a footer with next commands.

### Meetings by Date (`date <YYYY-MM-DD>`)

Extract the date from arguments (everything after "date "). Use `created_after`/`created_before` (ISO 8601):

```bash
~/.claude/aidev-toolkit/scripts/fathom-api.sh "meetings?created_after=<DATE>T00:00:00Z&created_before=<DATE>T23:59:59Z" \
  '.items | map({title, recording_id, recording_start_time, recording_end_time, recorded_by: .recorded_by.name, external: (.calendar_invitees_domains_type == "one_or_more_external")})'
```

If `next_cursor` is not null in the response, fetch the next page by appending `&cursor=<NEXT_CURSOR>` to the endpoint.

Display same table format as list. If no results, note that no meetings were recorded on that date.

### Today's Meetings (`today`)

```bash
date +%Y-%m-%d
```

```bash
~/.claude/aidev-toolkit/scripts/fathom-api.sh "meetings?limit=50" \
  '[.items[] | select(.recording_start_time | startswith($today))] | map({title, recording_id, recording_start_time, recording_end_time, recorded_by: .recorded_by.name, external: (.calendar_invitees_domains_type == "one_or_more_external")})' \
  --arg today "<TODAY>"
```

Display same table format as list.

### External Meetings (`external`)

```bash
~/.claude/aidev-toolkit/scripts/fathom-api.sh "meetings?limit=20" \
  '[.items[] | select(.calendar_invitees_domains_type == "one_or_more_external")] | map({title, recording_id, recording_start_time, recording_end_time, recorded_by: .recorded_by.name, external: true})'
```

### Search Meetings (`search <query>`)

Extract the query from arguments (everything after "search "). The API doesn't support search, so fetch and filter locally:

```bash
~/.claude/aidev-toolkit/scripts/fathom-api.sh "meetings?limit=200" \
  '[.items[] | select(.title | ascii_downcase | contains($q | ascii_downcase))] | map({title, recording_id, recording_start_time, recording_end_time, recorded_by: .recorded_by.name, external: (.calendar_invitees_domains_type == "one_or_more_external")})' \
  --arg q "<query>"
```

### View Meeting (`view <recording_id>`)

Extract the recording_id from arguments.

```bash
~/.claude/aidev-toolkit/scripts/fathom-api.sh "meetings?limit=200" \
  '.items | map(select(.recording_id == $id)) | .[0]' \
  --argjson id <recording_id>
```

Display formatted:

```text
Meeting: <title>
================

Date:        <date> (<day of week>)
Time:        <start> - <end> UTC (<duration>)
Recorded by: <name> (<email>)
Team:        <team>

Participants (<count>):
  - Name (email) [EXTERNAL]
  - Name (email)
  ...

Links:
  Fathom: <url>
  Share:  <share_url>

Commands:
  /fathom transcript <id>  Get full transcript
  /fathom summary <id>     AI summary
```

### Get Transcript (`transcript <recording_id>`)

Extract the recording_id from arguments.

```bash
~/.claude/aidev-toolkit/scripts/fathom-api.sh "recordings/<recording_id>/transcript" \
  '.transcript[] | "[\(.timestamp)] \(.speaker.display_name): \(.text)"' -r
```

Display with header showing meeting title (fetch from meetings endpoint first if needed).

If transcript is very long (>100 entries), show first 50 and note that full output was saved.

### Summary (`summary <recording_id>`)

Extract the recording_id from arguments.

1. First fetch the meeting details (via `view`) to get the title
2. Fetch the full transcript (via `transcript`)
3. Analyze the transcript and provide:

```text
Meeting Summary: <title>
========================

## Key Points
- <bullet points of main discussion topics>

## Decisions Made
- <any decisions that were reached>

## Action Items
- <who> will <do what> by <when if mentioned>

## Open Questions
- <unresolved items or things needing follow-up>

## Participants & Contributions
- <name>: <brief note on their role/contributions>
```

## API Reference

| Endpoint | Method | Description |
|----------|--------|--------------|
| `/meetings` | GET | List meetings |
| `/recordings/{id}/transcript` | GET | Get transcript for a recording |

### `/meetings` Query Parameters

| Parameter | Type | Description |
|-----------|------|--------------|
| `created_after` | string | ISO 8601 timestamp — return meetings created after this |
| `created_before` | string | ISO 8601 timestamp — return meetings created before this |
| `cursor` | string | Pagination cursor (from `next_cursor` in previous response) |
| `recorded_by[]` | array | Filter by recorder email (pass multiple times) |
| `teams[]` | array | Filter by team name (pass multiple times) |
| `calendar_invitees_domains[]` | array | Filter by invitee domain |
| `calendar_invitees_domains_type` | string | `all`, `only_internal`, or `one_or_more_external` |
| `include_summary` | boolean | Include summary in response (default: false) |
| `include_transcript` | boolean | Include transcript in response (default: false) |
| `include_action_items` | boolean | Include action items (default: false) |

## Response Fields

| Field | Description |
|-------|--------------|
| `title` | Meeting title |
| `recording_id` | Unique ID for transcript lookup |
| `url` | Direct Fathom link |
| `share_url` | Shareable link |
| `recording_start_time` | ISO timestamp |
| `recording_end_time` | ISO timestamp |
| `recorded_by` | Object: `name`, `email`, `team` |
| `calendar_invitees` | Array: `name`, `email`, `is_external` |
| `calendar_invitees_domains_type` | `only_internal` or `one_or_more_external` |

## Important Notes

- The API key lives at `~/.config/fathom/config` (`FATHOM_API_KEY=...`), per-user, never checked into any repo.
- Every user needs their own key scoped to their own Fathom account — there is no shared or username-gated access.

## Error Handling

If API returns an error or empty response, display:

```text
Fathom API Error

Could not fetch data. Check that:
- API key is valid (~/.config/fathom/config)
- Recording ID exists
- You have access to this recording
```
