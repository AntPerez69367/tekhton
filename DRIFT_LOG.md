# Drift Log

## Metadata
- Last audit: 2026-04-01
- Runs since audit: 1

## Unresolved Observations
(none)

## Resolved
- [RESOLVED 2026-04-01] On the Watchtower dasboard the Trends screen has a "recent runs" section that for each run generates more than one line, many of which are blank and marked as "HUMAN FEAT". These appear to be getting generated with 0 turns and 0s between each run. Sometimes 1, somtimes upwards of 9 of them. This is likely a bug in the code that generates the trends data for the dashboard, causing it to create multiple entries per run instead of just one."] lib/dashboard_parsers.sh:380-453 — `_parse_run_summaries_from_files` (legacy RUN_SUMMARY_*.json path) has no zero-turn filter. This is intentional since those files are written by successful pipeline completions rather than the ERR trap, but the two paths now have subtly different filtering contracts. A brief comment on the legacy function noting why no filter is needed would prevent future confusion.
- [RESOLVED 2026-04-01] On the Watchtower dasboard the Trends screen has a "recent runs" section that for each run generates more than one line, many of which are blank and marked as "HUMAN FEAT". These appear to be getting generated with 0 turns and 0s between each run. Sometimes 1, somtimes upwards of 9 of them. This is likely a bug in the code that generates the trends data for the dashboard, causing it to create multiple entries per run instead of just one."] lib/dashboard_parsers.sh:203-261 (Python) vs 275-374 (bash) — The Python path filters within the last `depth` JSONL lines, while the bash path counts only filtered records toward `depth`. For metrics.jsonl files with many crash records, the two paths could return different counts when `depth` is a binding constraint. Not a correctness bug for normal usage, but worth a comment.
