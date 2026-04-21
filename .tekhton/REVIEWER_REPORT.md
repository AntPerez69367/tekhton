# Reviewer Report

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `tests/test_tui_stage_wiring.sh` is 638 lines, over the 300-line soft ceiling. Growth is expected as M110 lifecycle tests were added, but consider splitting into `test_tui_stage_wiring.sh` (M97–M109 tests) and `test_tui_lifecycle.sh` (M110 lifecycle tests) in a future cleanup pass.

## Coverage Gaps
- `lib/pipeline_order_policy.sh` has no dedicated unit tests for `get_stage_policy`, `get_stage_array_key`, or `get_run_stage_plan` in the Python test suite. Shell-level coverage in `test_tui_stage_wiring.sh` exercises these functions indirectly, but a focused `tests/test_pipeline_order_policy.sh` would close the gap cleanly.

## Drift Observations
- `lib/pipeline_order_policy.sh:47` — `get_stage_array_key` carries a "Keep them in sync manually" comment acknowledging a known divergence between `_STAGE_*` associative-array keys (`reviewer`, `tester`, `tester_write`) and display labels (`review`, `tester`, `tester-write`). This is intentional debt, clearly documented, but worth resolving when `_STAGE_*` arrays migrate to display labels.
