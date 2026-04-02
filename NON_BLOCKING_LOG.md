# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-01 | "[BUG] On the Watchtower dasboard the Trends screen has a "recent runs" section that for each run generates more than one line, many of which are blank and marked as "HUMAN FEAT". These appear to be getting generated with 0 turns and 0s between each run. Sometimes 1, somtimes upwards of 9 of them. This is likely a bug in the code that generates the trends data for the dashboard, causing it to create multiple entries per run instead of just one."] tests/test_dashboard_parsers_bugfix.sh:8 — File header comment lists "Bug #1, #2, #3" but the new zero-turn filtering fix is effectively Bug #4; the comment is stale and could confuse future readers.
(none)

## Resolved
