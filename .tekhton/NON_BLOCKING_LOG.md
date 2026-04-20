# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [x] [2026-04-20 | "M107: TUI Stage Wiring: All Stages Instrumented"] `tekhton.sh` pipeline loop `tui_stage_end` reads `_STAGE_TURNS[$_stage_name]` / `_STAGE_DURATION[$_stage_name]` / `_STAGE_BUDGET[$_stage_name]` using the internal pipeline stage name (`review`, `test_verify`, `test_write`) as the key, but the dashboard arrays for those stages are populated under different keys (`reviewer`, `tester`, `tester_write`). Result: the turn-count and duration fields in the completed pill entry show "0/0 0s" for these three stages. The label and activation/completion transitions are correct; only the metadata fields are wrong. This is a pre-existing keying inconsistency that the spec acknowledges by using `:-0` defaults — not introduced by M107, but now visible via the TUI. Log for future cleanup.
- [ ] [2026-04-20 | "M107: TUI Stage Wiring: All Stages Instrumented"] `tui_stage_begin` is called before the `should_run_stage` check in the pipeline loop (line 2341 is before the `case` block, line 2502 `tui_stage_end` is after). When a user resumes with `--start-at review`, the coder, docs, and security pills will flash active→complete instantly with 0/0 turns, appearing as skipped rather than grayed-out. Cosmetically confusing for resume runs but harmless functionally. Scope gap; not required by M107 acceptance criteria.
- [ ] [2026-04-20 | "M106"] `get_stage_display_label`'s `*` fallback uses underscore-to-hyphen replacement (`${1//_/-}`) while `get_display_stage_order`'s `*` case passes internal names unmodified. A future stage added only to the pipeline order will produce different labels from each function until explicitly mapped in both.

## Resolved
