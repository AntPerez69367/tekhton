# Reviewer Report — M107 TUI Stage Wiring

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `tekhton.sh` pipeline loop `tui_stage_end` reads `_STAGE_TURNS[$_stage_name]` / `_STAGE_DURATION[$_stage_name]` / `_STAGE_BUDGET[$_stage_name]` using the internal pipeline stage name (`review`, `test_verify`, `test_write`) as the key, but the dashboard arrays for those stages are populated under different keys (`reviewer`, `tester`, `tester_write`). Result: the turn-count and duration fields in the completed pill entry show "0/0 0s" for these three stages. The label and activation/completion transitions are correct; only the metadata fields are wrong. This is a pre-existing keying inconsistency that the spec acknowledges by using `:-0` defaults — not introduced by M107, but now visible via the TUI. Log for future cleanup.
- `tui_stage_begin` is called before the `should_run_stage` check in the pipeline loop (line 2341 is before the `case` block, line 2502 `tui_stage_end` is after). When a user resumes with `--start-at review`, the coder, docs, and security pills will flash active→complete instantly with 0/0 turns, appearing as skipped rather than grayed-out. Cosmetically confusing for resume runs but harmless functionally. Scope gap; not required by M107 acceptance criteria.

## Coverage Gaps
- None

## ACP Verdicts
None present in CODER_SUMMARY.md.

## Drift Observations
- `stages/review.sh` Jr-after-Sr path (lines 294–303): when `HAS_SIMPLE > 0` fires after Sr rework, the Jr Coder `run_agent` call has no `tui_stage_begin`/`tui_stage_end` brackets. The coder summary notes this is intentional ("Jr-after-Sr pill-sharing path is deliberately left unwired per spec"), and the spec §5 confirms it. Noted here as a drift observation for future audit in case the reasoning changes.
