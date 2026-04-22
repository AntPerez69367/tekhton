## Planned Tests
- [x] `tests/test_run_op_lifecycle.sh` — M115 substage migration: 18 tests covering passthrough, idle/working/idle transitions, current_substage_label in JSON, parent stage_label preserved, stages_complete not appended, exit-code preservation on success/failure, heartbeat cleanup, stub override; current_operation field retired
- [x] `tools/tests/test_tui.py` — `test_timings_panel_working_row`: working state renders substage breadcrumb via current_substage_label; current_operation absent from _empty_status and _tui_json_build_status
- [x] `tools/tests/test_tui_render_timings.py` — `TestSubstageBreadcrumb.test_substage_breadcrumb_in_working_state`: shell-op working state renders parent » op breadcrumb with blanked turns column; missing substage keys tolerated for backward compatibility

## Test Run Results
Passed: 424 shell + 183 Python  Failed: 0

## Bugs Found
None

## Files Modified
- [x] `tests/test_run_op_lifecycle.sh`
- [x] `tools/tests/test_tui.py`
- [x] `tools/tests/test_tui_render_timings.py`
