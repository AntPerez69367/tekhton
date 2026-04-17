# Reviewer Report — M93: Rejection Artifact Preservation

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
None

## Simple Blockers (jr coder)
None

## Non-Blocking Notes
- `_save_orchestration_state` is not directly unit-tested — the test suite covers `_choose_resume_start_at` exhaustively, but there is no assertion that the `Notes` field in `PIPELINE_STATE.md` actually contains the restoration string, nor that `resume_flags` uses `_RESUME_NEW_START_AT` rather than `START_AT`. An integration test that stubs `finalize_run` and `write_pipeline_state` would close this gap, but the logic is simple and correct on inspection.

## Coverage Gaps
- No test exercises `_save_orchestration_state()` end-to-end (Notes field augmentation, resume_flags value). The stubbing overhead is non-trivial; log as a coverage gap for future hardening.

## Drift Observations
None

---

**Review notes:**

`_choose_resume_start_at` (orchestrate_helpers.sh:188–221) — Logic is correct. Resolution order (in-run reviewer → archived reviewer → in-run tester → archived tester → START_AT fallback) is implemented cleanly with early returns and no shared-state clobbering. Using `cp` (not `mv`) to restore the archived report is the right call — the archive entry stays intact.

`tekhton.sh` archive loop — The `case "$f"` pattern arms (`*REVIEWER_REPORT*`, `*TESTER_REPORT*`) match correctly against the original full-path value of `$f`, and `$ARCHIVE_NAME` (the destination after `mv`) is what gets recorded. Ordering is correct.

`_save_orchestration_state` integration — The call to `_choose_resume_start_at` happens after `finalize_run` (which may archive additional files) and before `write_pipeline_state` (which consumes `resume_flags`). The sequence is correct.

Test file — 8 scenarios, 20 assertions. Scenario 6.3 correctly verifies the tester file is NOT restored when the reviewer wins. Test 8 correctly uses a subshell capture for log verification only (globals from a subshell would not propagate back, but test 8 doesn't assert on globals). All `assert_eq` / `assert_file_eq` checks are well-formed.
