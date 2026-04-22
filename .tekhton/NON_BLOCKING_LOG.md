# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-21 | "Implement Milestone 113: TUI Hierarchical Substage API"] `tui_substage_end` accepts LABEL and VERDICT args for call-site symmetry but immediately discards both — the function body contains no reference to `$1` or `$2`. The comment documents this intent, but linters may eventually flag unused positional parameters. A future cleanup could add explicit `local _label="${1:-}" _verdict="${2:-}"` to silence tools.
- [ ] [2026-04-21 | "Implement Milestone 113: TUI Hierarchical Substage API"] `tui_stage_end` triggers three status file writes when a substage is auto-closed: one from `tui_append_event` inside `_tui_autoclose_substage_if_open`, one from `tui_finish_stage`, and one from the final `_tui_write_status` at end of `tui_stage_end`. All are atomic (tmp→mv), so no correctness impact — worth a consolidation pass in a later cleanup milestone.
- [x] [2026-04-21 | "Implement Milestone 113: TUI Hierarchical Substage API"] `_json_field` in `tests/test_tui_substage_api.sh` shell-interpolates `$_TUI_STATUS_FILE` and `$1` directly into a Python `-c "..."` string literal (`open('$_TUI_STATUS_FILE')`). Safe for temp paths and simple field-name arguments, but fragile if a path ever contains a single-quote. A more robust pattern passes the path via sys.argv instead. Worth standardizing across TUI test helpers.
- [ ] [2026-04-21 | "Implement Milestone 110: TUI Stage Lifecycle Semantics and Timings Coherence"] [lib/milestone_split_dag.sh:77-78] Security agent flagged a LOW path-traversal risk: `sub_file` is written without an explicit `*/*` guard, relying solely on `_slugify` to sanitize LLM-generated content. The fix is one line (`[[ "$sub_file" == */* ]] && return 1`). Pre-existing from M111; surfaced here for cleanup-pass tracking.
- [ ] [2026-04-21 | "Implement Milestone 110: TUI Stage Lifecycle Semantics and Timings Coherence"] [stages/coder_prerun.sh:69, stages/tester_fix.sh:164] Mixed `emit_event` guard idiom (`command -v` vs `declare -f`). Introduced in M112, carried forward from the M112 review. Cleanup stage owns the resolution.
- [ ] [2026-04-21 | "M112"] `stages/coder_prerun.sh:69` and `stages/tester_fix.sh:164` — new dedup skip-event guards use `command -v emit_event &>/dev/null` while every other emit_event check in both files uses `declare -f emit_event &>/dev/null`. Both succeed for bash functions but `declare -f` is canonical and is the pattern used throughout the codebase. Align for consistency.
- [ ] [2026-04-21 | "M111"] `lib/milestone_split_dag.sh:78` — Security LOW (flagged by security agent, fixable): `echo "$sub_block" > "${milestone_dir}/${sub_file}"` relies solely on `_slugify` to strip path separators. Adding `[[ "$sub_file" == */* ]] && return 1` immediately before the write makes traversal safety unconditional regardless of future changes to `_slugify`.

## Resolved
