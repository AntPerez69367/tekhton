# Coder Summary
## Status: COMPLETE
## What Was Implemented
- Created `_normalize_markdown_blank_runs()` helper in new `lib/notes_core_normalize.sh` that collapses blank-line runs in markdown files: strips leading/trailing blanks, collapses interior runs of >= 2 blank lines to one, and preserves blank lines inside fenced code blocks
- Integrated the helper into 5 call sites across 3 files:
  - `clear_completed_human_notes()` in `lib/notes.sh` — normalizes after removing [x] items
  - `clear_completed_nonblocking_notes()` in `lib/drift_cleanup.sh` — normalizes after moving [x] from Open to Resolved
  - `clear_resolved_nonblocking_notes()` in `lib/drift_cleanup.sh` — normalizes after clearing Resolved section
  - `mark_note_resolved()` in `lib/notes_cleanup.sh` — normalizes after sed substitution
  - `mark_note_deferred()` in `lib/notes_cleanup.sh` — normalizes after sed substitution
- Created comprehensive test suite `tests/test_notes_normalization.sh` with 5 scenarios: idempotency on clean file (SHA-256 stability over 5 runs), interior-blank collapse after [x] removal, description block removal with trailing blank, fenced code block preservation, and standalone normalization idempotency
- Added blank-line stability assertions to `tests/test_clear_resolved_nonblocking_notes.sh` and `tests/test_cleanup_notes.sh`
- Fixed 2 existing tests that sourced `drift_cleanup.sh` or `notes.sh` without the new normalize dependency: `test_drift_cleanup.sh`, `test_startup_cleanup.sh`
- Removed trailing blank line from `lib/drift_cleanup.sh` to stay at 300-line ceiling
- Bumped `TEKHTON_VERSION` to `3.73.0`
- Added `notes_core_normalize.sh` to CLAUDE.md repository layout

## Root Cause (bugs only)
Blank-line accumulation: `clear_completed_human_notes()` and `clear_resolved_nonblocking_notes()` drop items from markdown files by skipping matching lines when streaming to a tmpfile, but pre-existing blank lines around removed items are preserved. Over successive pipeline runs, these orphaned blank lines accumulate, making files grow steadily. The same pattern exists in `clear_completed_nonblocking_notes()`. The fix applies a post-processing normalization pass after every rewrite that could leave orphaned blanks.

## Files Modified
- `lib/notes_core_normalize.sh` (NEW) — `_normalize_markdown_blank_runs()` helper
- `lib/notes.sh` — call helper from `clear_completed_human_notes` after rewrite
- `lib/drift_cleanup.sh` — call helper from `clear_completed_nonblocking_notes` and `clear_resolved_nonblocking_notes`; removed trailing blank line
- `lib/notes_cleanup.sh` — call helper from `mark_note_resolved` and `mark_note_deferred`
- `tekhton.sh` — source `notes_core_normalize.sh` before `notes_core.sh`; bump version to 3.73.0
- `tests/test_notes_normalization.sh` (NEW) — 5-scenario regression test suite
- `tests/test_clear_resolved_nonblocking_notes.sh` — source normalize helper; add blank-line stability assertion
- `tests/test_cleanup_notes.sh` — source normalize helper; add blank-line stability assertions
- `tests/test_drift_cleanup.sh` — source normalize helper (fix broken dependency)
- `tests/test_startup_cleanup.sh` — source normalize helper (fix broken dependency)
- `CLAUDE.md` — add `notes_core_normalize.sh` to repository layout

## Human Notes Status
No human notes to address.
