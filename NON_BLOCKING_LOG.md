# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-01 | "Resolve all 2 unresolved architectural drift observations in DRIFT_LOG.md."] [lib/dashboard_parsers.sh:362] Security agent flagged `task_label` interpolated into JSON string in the bash fallback of `_parse_run_summaries_from_jsonl` without `_json_escape()`. Pre-existing issue not introduced by this change (LOW severity) — warrants a dedicated fix pass.
- [ ] [2026-04-01 | "Resolve all 2 unresolved architectural drift observations in DRIFT_LOG.md."] [lib/dashboard_parsers.sh:448] Security agent flagged `milestone`, `run_type`, `task_label`, `outcome` interpolated into JSON without `_json_escape()` in the `_parse_run_summaries_from_files` sed fallback. Pre-existing, LOW severity.
- [ ] [2026-04-01 | "Resolve all 2 unresolved architectural drift observations in DRIFT_LOG.md."] [lib/dashboard_parsers.sh:35] Security agent flagged PID-based tmpfile suffix in `_write_js_file`; `mktemp` preferred. Pre-existing, LOW severity.
(none)

## Resolved
