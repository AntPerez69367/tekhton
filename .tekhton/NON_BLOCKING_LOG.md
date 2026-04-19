# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [x] [2026-04-19 | "M99"] TUI event messages include the level prefix in the `msg` field (e.g. `"[!] problem"`) via `notify_msg` in `_out_emit`, whereas pre-M99 the raw message was forwarded to `_tui_notify`. If `tui_render.py` adds a visual level indicator based on the `level` field, the TUI event panel could show double-prefixed messages. Should be verified against the Python renderer.

## Resolved
