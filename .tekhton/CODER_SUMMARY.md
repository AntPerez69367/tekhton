# Coder Summary

## Status: COMPLETE

## What Was Implemented

Milestone 115 — `run_op` migration onto the M113 substage API and full
retirement of the `_TUI_OPERATION_LABEL` bash global + `current_operation`
JSON field.

- `run_op` in `lib/tui_ops.sh` now calls `tui_substage_begin "$_label"` /
  `tui_substage_end "$_label" PASS|FAIL` around the wrapped command, letting
  the M113 substage globals (`_TUI_CURRENT_SUBSTAGE_LABEL`,
  `_TUI_CURRENT_SUBSTAGE_START_TS`) carry the op label into the status JSON.
  Heartbeat subprocess, passthrough-on-inactive, and exit-code preservation
  are all unchanged.
- `_tui_json_build_status` in `lib/tui_helpers.sh` no longer emits the
  `current_operation` field. `_empty_status()` in `tools/tui.py` also drops it.
- The Python renderer (`tools/tui_render.py:_build_working_bar` and
  `tools/tui_render_timings.py:_build_timings_panel`) now sources the working-
  row label from `current_substage_label` via the M114 breadcrumb path, so
  shell ops and in-agent substages render through a single code path. The
  turns column is blanked during `working` state and during any `running`
  state with an active substage (shell ops do not use turns; parent counter
  is stale during an agent substage).
- `run_op` does NOT mutate `stage_label` or append to `stages_complete` —
  the parent pipeline stage stays on screen and its pill remains in the
  running state while the sub-op executes.
- JSON schema compatibility: new-bash → old-Python tolerates the missing
  `current_operation`; old-bash → new-Python tolerates the missing
  `current_substage_label` (both renderers use `.get(...) or ""`).

## Root Cause (bugs only)

N/A — milestone implementation, not a bug fix.

## Files Modified

| File | Change |
|------|--------|
| `lib/tui_ops.sh` | Dropped `_TUI_OPERATION_LABEL` global; rewrote `run_op` on the M113 substage API. |
| `lib/tui_helpers.sh` | Removed `current_operation` from `_tui_json_build_status` output. |
| `tools/tui.py` | Dropped `current_operation` from `_empty_status()`. |
| `tools/tui_render.py` | `_build_working_bar` now renders `"{stage} » {substage}"` breadcrumb from `current_substage_label`. |
| `tools/tui_render_timings.py` | Removed working-state override; substage breadcrumb + blanked turns apply to both `running` and `working`. |
| `tests/test_run_op_lifecycle.sh` | Full rewrite onto substage contract: 18 tests (passthrough, idle/working/idle transitions, substage label in JSON, parent stage label preserved, stages_complete not appended, exit-code preservation on success/failure, heartbeat cleanup, stub overrides). |
| `tools/tests/test_tui.py` | Dropped `current_operation` stubs from timings panel tests; rewrote `test_timings_panel_working_row` to assert the substage breadcrumb + blank turns column. |
| `tools/tests/test_tui_render_timings.py` | `test_live_stage_working` now exercises the substage path; inverted `test_substage_ignored_in_working_state` → `test_substage_breadcrumb_in_working_state` (working state now DOES render the breadcrumb under M115). |
| `.tekhton/CODER_SUMMARY.md` | This file. |

## Acceptance Criteria Self-Check

- [x] `run_op` wraps its body in `tui_substage_begin` / `tui_substage_end`
      with the call-site label (verified by test_run_op_lifecycle.sh Tests
      6–15 and `declare -f run_op` assertion in Test 17).
- [x] `_TUI_OPERATION_LABEL` global removed — `grep -rn _TUI_OPERATION_LABEL
      lib/ stages/ tests/` returns empty.
- [x] `current_operation` JSON field removed — verified by Test 6
      (asserts absence in `_tui_json_build_status` output).
- [x] TUI renderer sources the working-row label from
      `current_substage_label` via the M114 breadcrumb path.
- [x] `run_op` preserves parent `stage_label` (Test 9) and does not append
      to `stages_complete` (Test 10).
- [x] Exit code preservation (Tests 1–5 passthrough, Test 14 TUI-active
      failure path).
- [x] Backwards-compat for old-bash → new-Python: `_build_timings_panel`
      and `_build_working_bar` both tolerate missing `current_substage_label`
      (verified by `test_missing_substage_keys_tolerated`).
- [x] All files under 300-line ceiling: `tui_ops.sh`=299, `tui_helpers.sh`=227,
      `tui_render.py`=241, `tui_render_timings.py`=115, `tui.py`=203.
- [x] shellcheck clean on `tekhton.sh lib/*.sh stages/*.sh`.
- [x] Full bash test suite: 424 passed, 0 failed.
- [x] Full Python test suite: 183 passed.

## Human Notes Status

No unchecked human notes passed to this run.
