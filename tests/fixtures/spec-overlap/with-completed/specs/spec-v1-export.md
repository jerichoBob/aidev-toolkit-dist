---
version: 1
name: csv-export
status: in-progress
---

# CSV export

## What (Requirements)

### User Stories

- **US-1**: As an analyst, I want to export results as CSV so that I can open them in a spreadsheet.

### Acceptance Criteria

- AC-1: Given a result set, when the user exports, then a CSV file is produced.
- AC-2: Given more than 10000 rows, then the export streams instead of loading all rows.

### Out of Scope

- AC-99: This line is outside the criteria section and must not be indexed.
