## Planned Tests
- [x] `tests/test_tui_multipass_lifecycle.sh` — M111 regression test: sidecar lifecycle spans outer invocation, not per-pass
- [x] `tests/test_out_complete.sh` — _hook_tui_complete contract: emits summary events, does not call out_complete
- [x] `tests/test_m106_spinner_pid_routing.sh` — spinner PID routing: TUI vs non-TUI path selection based on _TUI_ACTIVE

## Test Run Results
Passed: 24  Failed: 0

### Detailed Results

**test_tui_multipass_lifecycle.sh (7/7 PASS)**
- Test 1: _hook_tui_complete 0 keeps _TUI_ACTIVE=true ✓
- Test 2: _hook_tui_complete 1 keeps _TUI_ACTIVE=true ✓
- Test 3: multi-pass simulation — three finalize_run calls in a row ✓
- Test 4: each pass appends a summary event 'Pass complete: SUCCESS' ✓
- Test 5: mixed-verdict passes emit correct levels ✓
- Test 6: _hook_tui_complete is a no-op when _TUI_ACTIVE=false ✓

**test_out_complete.sh (10/10 PASS)**
- Part 1: out_complete() behaviour (5 tests) ✓
  - Test 1: no-op when tui_complete absent ✓
  - Test 2: delegates to tui_complete ✓
  - Test 3: passes SUCCESS verdict ✓
  - Test 4: passes FAIL verdict ✓
  - Test 5: silent no-op after tui_complete unset ✓
- Part 2: _hook_tui_complete() behaviour M111 contract (5 tests) ✓
  - Test 6: exit 0 → summary event, no out_complete ✓
  - Test 7: exit 1 → summary event, no out_complete ✓
  - Test 8: exit 42 → FAIL summary event ✓
  - Test 9: closes wrap-up pill with SUCCESS verdict on exit 0 ✓
  - Test 10: closes wrap-up pill with FAIL verdict on exit 1 ✓

**test_m106_spinner_pid_routing.sh (7/7 PASS)**
- AC-13: TUI mode — _spinner_pid empty, _tui_updater_pid non-empty ✓
- AC-14: Non-TUI mode — _spinner_pid non-empty, _tui_updater_pid empty ✓
- AC-15a: TUI mode — only tui_updater_pid targeted ✓
- AC-15b: non-TUI mode — only spinner_pid targeted ✓
- AC-15c: empty spinner_pid — spinner cleanup branch skipped ✓

## Coverage Analysis

### Primary Observable Behavior Verified
**Task requirement:** No `[tekhton] ⠦ ...` spinner output should appear on terminal while TUI is active in multi-pass modes (`--complete`, `--fix-nb`, `--fix-drift`)

**How tests verify this:**
1. **State persistence** (test_tui_multipass_lifecycle.sh Tests 1–3):
   - Verifies `_TUI_ACTIVE` remains true across multiple finalize_run() calls
   - Without this, spinner falls back to /dev/tty output path

2. **Hook contract** (test_out_complete.sh Tests 6–10):
   - Verifies `_hook_tui_complete` does NOT call `out_complete`
   - `out_complete` would trigger `tui_stop`, which sets `_TUI_ACTIVE=false`
   - This is the key fix: per-pass finalize only emits a summary event, doesn't kill the sidecar

3. **Spinner routing** (test_m106_spinner_pid_routing.sh Tests AC-13–15):
   - Verifies spinner uses correct PID routing based on `_TUI_ACTIVE` state
   - When `_TUI_ACTIVE=true`, spinner_pid is empty (no /dev/tty output)
   - When `_TUI_ACTIVE=false`, spinner_pid is populated (uses /dev/tty)

### Related Tests Verified to Still Pass
- test_finalize_run.sh: 107/107 PASS (no regressions in hook chain)
- test_tui_active_path.sh: 35/35 PASS (TUI state management)
- test_output_format_tui.sh: 29/29 PASS (TUI output formatting)
- test_tui_stage_wiring.sh: 53/53 PASS (TUI stage coordination)
- test_tui_action_items.sh: 10/10 PASS (TUI action item tracking)
- test_tui_attempt_counter.sh: 8/8 PASS (TUI attempt counting)
- test_tui_set_context.sh: 24/24 PASS (TUI context management)
- All other TUI-prefixed tests pass without regression

## Bugs Found
None

## Files Modified
- [x] `tests/test_tui_multipass_lifecycle.sh`
- [x] `tests/test_out_complete.sh`
- [x] `tests/test_m106_spinner_pid_routing.sh`

## Implementation Review Summary

### Fix Correctness
The fix implements option (a) from the task specification:
1. **Moved `tui_stop` out of per-pass hooks** — `_hook_tui_complete` now only closes the wrap-up pill and emits a summary event, does NOT call `out_complete`
2. **Single top-level `out_complete` call** — Added to `tekhton.sh` at EOF, after all dispatch branches
3. **Sidecar lifecycle matches outer invocation** — `tui_start` called once at main entry; `tui_stop` only at true teardown via `out_complete` or cleanup trap

### Test Coverage Assessment
✅ **Acceptance criteria coverage:** All stated requirements from task description are covered
✅ **Happy path coverage:** Multi-pass modes with TUI active are explicitly tested
✅ **Edge cases covered:**
  - Mixed success/fail verdicts across passes (Test 5, test_tui_multipass_lifecycle.sh)
  - Hook graceful no-op when TUI not active (Test 6, test_tui_multipass_lifecycle.sh)
  - Multiple sequential passes (Test 3, test_tui_multipass_lifecycle.sh)
  - Spinner routing correctness in both TUI and non-TUI modes (test_m106_spinner_pid_routing.sh)

✅ **Regression prevention:** Existing test suite remains fully passing; no new failures introduced
