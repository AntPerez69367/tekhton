# Reviewer Report — M113: TUI Hierarchical Substage API

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `tui_substage_end` accepts LABEL and VERDICT args for call-site symmetry but immediately discards both — the function body contains no reference to `$1` or `$2`. The comment documents this intent, but linters may eventually flag unused positional parameters. A future cleanup could add explicit `local _label="${1:-}" _verdict="${2:-}"` to silence tools.
- `tui_stage_end` triggers three status file writes when a substage is auto-closed: one from `tui_append_event` inside `_tui_autoclose_substage_if_open`, one from `tui_finish_stage`, and one from the final `_tui_write_status` at end of `tui_stage_end`. All are atomic (tmp→mv), so no correctness impact — worth a consolidation pass in a later cleanup milestone.
- `_json_field` in `tests/test_tui_substage_api.sh` shell-interpolates `$_TUI_STATUS_FILE` and `$1` directly into a Python `-c "..."` string literal (`open('$_TUI_STATUS_FILE')`). Safe for temp paths and simple field-name arguments, but fragile if a path ever contains a single-quote. A more robust pattern passes the path via sys.argv instead. Worth standardizing across TUI test helpers.

## Coverage Gaps
- No explicit test case for `tui_substage_begin ""` (empty label) — the guard `[[ -z "$label" ]] && return 0` is present but untested directly.
- No explicit test for `tui_substage_begin` when `_TUI_ACTIVE=false` (standard TUI no-op pattern but lacks an M113-specific assertion).

## Drift Observations
- [lib/milestone_split_dag.sh:77-78] Security agent flagged a LOW path-traversal risk (pre-existing from M111): `sub_file` is written without an explicit `*/*` guard, relying solely on `_slugify` to sanitize LLM-generated content. Carried forward from M112 review; cleanup pass owns the one-line fix.
