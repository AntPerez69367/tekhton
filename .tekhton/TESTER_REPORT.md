## Planned Tests
- [x] `tests/test_tui_stage_completion.sh` — verify tui_stage_end records duration/turns for review and tester stages
- [x] `tools/tests/test_tui_render_timings.py` — run existing Python tests for time normalization and panel rendering
- [x] `tests/test_m66_full_stage_metrics.sh` — verify stage metrics are correctly computed and recorded for all stages

## Test Run Results
Passed: 603  Failed: 0

## Bugs Found
None

## Files Modified
- [x] `tests/test_tui_stage_completion.sh`

## Audit Rework

### HIGH Severity Fixes

- [x] **INTEGRITY**: Replaced trivially-true assertion in `test_tui_stage_end_duration`
  - **What was wrong**: Test called `sleep 2`, then passed hardcoded `"120s"` time string to `tui_stage_end`, then asserted the stored time was `>= 2s`. The assertion `120 >= 2` was always true regardless of actual elapsed time computation.
  - **Fix applied**: Renamed test to `test_tui_stage_end_elapsed_secs` and changed it to:
    - Remove the misleading `sleep 2`
    - Add a real sleep (1s) to generate measurable elapsed time
    - Pass `"0s"` as time string (caller responsibility)
    - Assert that `_TUI_AGENT_ELAPSED_SECS` >= 1 (the internally computed value)
  - **Rationale**: Tests the actual implementation behavior — `tui_stage_end` computes elapsed time from `_TUI_STAGE_START_TS` and stores it in `_TUI_AGENT_ELAPSED_SECS` (ref: `lib/tui_ops.sh:223-228`).

- [x] **COVERAGE**: Added `test_tui_stage_metrics_arrays` to exercise Bug #2 production path
  - **What was missing**: No test exercised the path in `tekhton.sh:2530-2538` where `_STAGE_DURATION[review]` and `_STAGE_TURNS[review]` arrays are passed to `tui_stage_end`. Bug #2 reports that review/tester show 0s/0 turns — the root cause is these arrays not being populated before the call.
  - **Fix applied**: New test that:
    - Declares and populates `_STAGE_DURATION`, `_STAGE_TURNS`, `_STAGE_BUDGET` arrays (as tekhton.sh does)
    - Calls `tui_stage_end` with values from those arrays
    - Verifies the values appear in the JSON output (90s duration, 8/15 turns)
  - **Rationale**: Tests the exact upstream production path that populates TUI metrics.

### LOW Severity Fixes

- [x] **EXERCISE**: Removed dead `sleep 2` at line 65
  - **Issue**: Added 2 real seconds to every test run with no effect on assertions (which tested hardcoded "120s", not elapsed time).
  - **Fix**: Removed the sleep; retained 1s sleep in new `test_tui_stage_end_elapsed_secs` where it's required.

### Findings Requiring Implementation Changes (Deferred)

- [ ] **INTEGRITY**: Pre-verified STALE-SYM entries in test output are false positives
  - **Issue**: The orphan detector in `lib/test_audit_detection.sh` flags POSIX builtins (bash, cat, cd, etc.) as orphaned symbols.
  - **Action**: Implementation change required — filter POSIX builtins from the symbol scan.
  - **Status**: Deferred; requires implementation work outside test scope.

### Test Results After Audit Rework

All three test files pass:
- `tests/test_tui_stage_completion.sh`: 5 tests PASS
- `tools/tests/test_tui_render_timings.py`: 26 tests PASS (unchanged — no findings)
- `tests/test_m66_full_stage_metrics.sh`: 27 assertions PASS (unchanged — no findings)
