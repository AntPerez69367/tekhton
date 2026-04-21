## Test Audit Report

### Audit Summary
Tests audited: 6 files, 24 test functions
Verdict: PASS

### Findings

#### EXERCISE: Init array ownership tests simulate logic rather than call implementation
- File: tests/test_nonblock_init_array_ownership.sh:11–93
- Issue: All four test functions reproduce the `lib/init.sh` condition block verbatim inside the test, rather than sourcing or calling `lib/init.sh`. The comment "Simulate the check in init.sh at line 161-163" is accurate — none of the tests exercise the real implementation. The condition `if [[ "${_WIZARD_VENV_CREATED:-}" == "true" ]]; then _INIT_FILES_WRITTEN+=(...)` is copy-pasted, so the tests verify that the pattern works in isolation, not that `init.sh` uses the pattern. If `init.sh` used a different variable name or different condition, all four tests would still pass.
- Severity: MEDIUM
- Action: Extract the bookkeeping gate into a dedicated helper (`_init_record_venv_artifacts`) that can be sourced and called directly. If `init.sh` side effects make sourcing impractical in the short term, add a comment to the test file documenting the coverage gap so future authors know to revisit it when the helper is extracted.

#### COVERAGE: Serena log separation test covers only the all-enabled happy path
- File: tests/test_nonblock_serena_log.sh:13–81
- Issue: The single test always sets `_WIZARD_NEEDS_VENV=true` and `_WIZARD_SERENA_ENABLED=true`. Not covered: (a) Serena disabled — asserting `serena_setup.log` is *not* created and `indexer_setup.log` is; (b) either setup script exiting non-zero — asserting the failure output still lands in the correct log; (c) `VERBOSE_OUTPUT=true` path — where output goes to stdout instead of either log file. The existing test adequately verifies the fix for Note 1 but leaves the adjacent paths unguarded.
- Severity: LOW
- Action: Add a `_test_serena_log_not_created_when_disabled` test that sets `_WIZARD_SERENA_ENABLED=false` and asserts `serena_setup.log` is absent.

#### ASSERTION: Intake filtering check uses prefix pattern instead of substring match
- File: tests/test_nonblock_stage_label_consistency.sh:126
- Issue: `_test_display_order_filtering` asserts `[[ "$display_order" != "intake"* ]]`, which only verifies the output does not *start* with "intake". If "intake" appeared mid-string the assertion would pass incorrectly. The intent is to confirm "intake" does not appear anywhere in the output. The complementary security-filtering check on line 147 correctly uses `*"security"*`.
- Severity: LOW
- Action: Change line 126 to `[[ "$display_order" != *"intake"* ]]` to match intent and the existing security-filtering assertion style.

#### NAMING: Error message in failure branch describes the wrong failure mode
- File: tests/test_nonblock_return_propagation.sh:31
- Issue: Inside `_test_return_failure`, the `then` branch (reached when `_wizard_run_setup_script` incorrectly returns 0 on a failing script) prints `"FAIL: _wizard_run_setup_script returned non-zero on successful script"`. The message is inverted — the problem would be that the function returned *zero* on a *failing* script. If a regression triggered this branch, the message would misdirect diagnosis.
- Severity: LOW
- Action: Change line 31 to `echo "FAIL: _wizard_run_setup_script returned 0 on a failing script (expected non-zero)"`.

### Notes

All six test files create their own fixtures in temporary directories and clean up via
`trap "rm -rf '$tmpdir'" EXIT`. None read from mutable pipeline state files (`.tekhton/`,
`.claude/logs/`, build reports, pipeline run artifacts). Isolation is clean across all files.

Assertions in `test_nonblock_return_propagation.sh`, `test_nonblock_wizard_signal.sh`,
`test_nonblock_serena_log.sh`, `test_nonblock_stage_label_consistency.sh`, and
`test_nonblock_tui_stage_guards.sh` were each cross-checked against the relevant
implementation. The explicit stage-mapping table in `_test_explicit_mappings` matches
`get_stage_display_label` in `lib/pipeline_order.sh:216–233` exactly. The `should_run_stage`
position arithmetic in `_test_start_at_coder`, `_test_start_at_review`, and
`_test_test_first_order` is correct for both standard and `test_first` pipeline orders.
The `_WIZARD_VENV_CREATED` export and `_wizard_reset_state` unset paths are correctly
exercised in `test_nonblock_wizard_signal.sh`. No orphaned test references were found;
no test exercises deleted files (`.tekhton/INTAKE_REPORT.md`, `.tekhton/JR_CODER_SUMMARY.md`).
