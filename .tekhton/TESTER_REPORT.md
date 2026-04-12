## Planned Tests
- [x] `tests/test_notes_normalization.sh` — normalize helper: idempotency, blank collapse, fenced code preservation
- [x] `tests/test_clear_resolved_nonblocking_notes.sh` — blank-line stability after resolved notes cleared
- [x] `tests/test_cleanup_notes.sh` — blank-line stability after mark_note_resolved / mark_note_deferred
- [x] `tests/test_drift_cleanup.sh` — drift cleanup with normalize dependency sourced
- [x] `tests/test_startup_cleanup.sh` — startup cleanup with normalize dependency sourced

## Test Run Results
Passed: 337  Failed: 0

## Bugs Found
None

## Files Modified
- [x] `tests/test_notes_normalization.sh`
- [x] `tests/test_clear_resolved_nonblocking_notes.sh`
- [x] `tests/test_cleanup_notes.sh`
- [x] `tests/test_drift_cleanup.sh`
- [x] `tests/test_startup_cleanup.sh`
