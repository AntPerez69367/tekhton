# Coder Summary

## Status: COMPLETE

## What Was Implemented
Truncated long stage labels in the TUI Stage Timings panel so a substage
breadcrumb like "wrap-up » running final static analyzer" no longer pushes
the right-aligned time/turns columns off-screen.

- Promoted `_truncate(s, limit)` from `tools/tui_render.py` into
  `tools/tui_render_common.py` so it can be reused by sibling render modules
  without creating a circular import through `tui_render`.
- Updated `tools/tui_render.py` to import `_truncate` from
  `tui_render_common` (re-exported via the existing `# noqa: F401` line so
  `tui_hold.py`'s `from tui_render import ... _truncate` continues to work
  unchanged).
- Imported `_truncate` in `tools/tui_render_timings.py` and applied a
  32-char cap (`_LABEL_MAX_CHARS`) to both completed-stage labels and the
  live-row `display_label` (which holds the breadcrumb form
  `f"{current_label} » {substage_label}"`). The column's existing
  `overflow="fold"` setting still acts as a backstop on narrow terminals.

## Root Cause (bugs only)
The Stage Timings panel sits in a ratio=1 child of the body (≈1/3 of the
screen). The first grid column was set to `no_wrap=False, overflow="fold"`
so wrapping would engage when content exceeded the available width, but in
practice Rich's `Table.grid` content-based allocation gave the long label
column whatever it asked for, pushing the right-justified time/turns
columns off the visible width before wrapping triggered. Capping the label
text at 32 chars before it reaches the grid keeps the row at one printable
line and leaves room for the time/turns cells.

## Files Modified
- `tools/tui_render_common.py` — added `_truncate(s, limit)` helper.
- `tools/tui_render.py` — removed the local `_truncate` definition; now
  imports it from `tui_render_common` (re-exported for `tui_hold`).
- `tools/tui_render_timings.py` — imported `_truncate`, added
  `_LABEL_MAX_CHARS = 32`, and applied truncation to both the completed-row
  label and the live-row `display_label` (substage breadcrumb).

## Docs Updated
None — no public-surface changes in this task. `_truncate` and
`_LABEL_MAX_CHARS` are internal renderer helpers; no CLI flag, config key,
JSON schema, or exported function signature changed.

## Human Notes Status
None — no human notes were listed for this task.

## Observed Issues (out of scope)
None.
