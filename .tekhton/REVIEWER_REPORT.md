# Reviewer Report — M115: run_op Substage Migration

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `run_op` sets `_TUI_AGENT_STATUS="idle"` after calling `tui_substage_end`, which itself writes the status file while the status is still "working" with an empty substage label. This produces one transitional write that renders as "Working…" before the final `idle` write. Harmless in practice (sub-millisecond window; renderer won't catch it), but setting `_TUI_AGENT_STATUS="idle"` before `tui_substage_end` would eliminate the ambiguous intermediate frame.

## Coverage Gaps
- None

## Drift Observations
- `tui_ops_substage.sh` is a runtime dependency of `run_op` (via `tui_substage_begin`/`tui_substage_end`), but the CLAUDE.md layout entry for `tui_ops.sh` still reads "M104 run_op wrapper + TUI update/event helpers" with no mention of the M113 substage dependency. A reader scanning the layout won't know the two modules are coupled.
