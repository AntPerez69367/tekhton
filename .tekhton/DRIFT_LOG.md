# Drift Log

## Metadata
- Last audit: 2026-04-19
- Runs since audit: 2

## Unresolved Observations
- [2026-04-19 | "M105"] `lib/orchestrate.sh` is 463 lines — 54% over the 300-line ceiling. Pre-existing and noted by coder; extraction is its own pass.
- [2026-04-19 | "M104"] `lib/tui_ops.sh` accesses globals declared in `lib/tui.sh` (`_TUI_ACTIVE`, `_TUI_RECENT_EVENTS`, `_TUI_STAGES_COMPLETE`, `_TUI_CURRENT_STAGE_*`, `_TUI_AGENT_*`, `_tui_write_status`) with no `# shellcheck source=tui.sh` directive. Consistent with the pre-existing gap in `tui_helpers.sh` — not new drift.

## Resolved
