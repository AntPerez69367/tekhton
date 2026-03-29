# Coder Summary
## Status: COMPLETE
## What Was Implemented
Fixed the Watchtower Trends "Recent Runs" section to show all historical runs instead of only the most recent one.

1. **`lib/finalize_summary.sh`**: After writing `RUN_SUMMARY.json`, now also copies it to a timestamped archive file (`RUN_SUMMARY_<TIMESTAMP>.json`) so historical run data accumulates across runs.

2. **`lib/dashboard_parsers.sh`**: Changed the glob pattern from `RUN_SUMMARY*.json` to `RUN_SUMMARY_*.json` to read only archived timestamped copies (avoiding double-counting the live file). Also added `task_label`, `timestamp`, and `team` fields to the python3 parser and `task_label` to the sed fallback, so the JS Recent Runs display has full data.

3. **Tests updated**: Updated `test_dashboard_data.sh` and `test_dashboard_parsers_bugfix.sh` to use the new `RUN_SUMMARY_<timestamp>.json` naming convention.

## Root Cause (bugs only)
`_hook_emit_run_summary()` wrote to a single `RUN_SUMMARY.json` file each run, overwriting the previous run's data. There was no archival step to preserve historical run summaries. The `_parse_run_summaries()` function's glob `RUN_SUMMARY*.json` only ever found 1 file, so the Trends page always showed exactly 1 run regardless of how many runs had been executed.

## Files Modified
- `lib/finalize_summary.sh` — Added timestamped archival copy of RUN_SUMMARY.json
- `lib/dashboard_parsers.sh` — Changed glob to `RUN_SUMMARY_*.json`, added missing fields to parsers
- `tests/test_dashboard_data.sh` — Updated test fixture filename
- `tests/test_dashboard_parsers_bugfix.sh` — Updated test fixture filenames (4 occurrences)

## Human Notes Status
- NOT_ADDRESSED: [BUG] Watchtower Trends page: Per-stage breakdown shows unclear arbitrary percentage in Last Run column, Budget Util is redundant, Avg Turns and Last Run are always identical, and Build stage row never populates (not in scope for this task)
- NOT_ADDRESSED: [BUG] Watchtower Reports page: Test Audit section never displays any information (not in scope for this task)
- NOT_ADDRESSED: [BUG] Watchtower Actions screen: Auto-refresh wipes all form fields every few seconds, making the screen unusable during a pipeline run. Actions screen has no live run data and should not refresh at all (not in scope for this task)
- NOT_ADDRESSED: [BUG] Watchtower Actions screen: Cannot add new Parallel Groups, only existing ones are selectable. New projects have only one (or zero) options available (not in scope for this task)
- NOT_ADDRESSED: [BUG] Watchtower: Live Run page uses minimal screen real estate and should be a persistent banner at the top of every page instead of its own page (not in scope for this task)
- NOT_ADDRESSED: [BUG] Watchtower: Auto-refresh applies to all pages instead of only Reports and Live Run, causing unnecessary reloads elsewhere (not in scope for this task)
- NOT_ADDRESSED: [BUG] Watchtower Trends page: Average stage times are incorrect. Tester shows 3:38 avg despite no run under 5 min; an 11-min run decreased the average to 3:21 instead of increasing it. The average run time shows as 8m50s when in actual fact most runs are well over 20 minutes, some reaching over an hour. This is critical for users to have an accurate expectation of how long runs will take and to see the impact of their optimizations. (not in scope for this task)
