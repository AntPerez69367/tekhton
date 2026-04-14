## Test Audit Report

### Audit Summary
Tests audited: 3 files, 26 test assertions
Verdict: PASS

### Findings

#### COVERAGE: DAG-disabled fallback assertion never exercises the "dependency tracking requires" note
- File: tests/test_milestone_progress_display.sh:139
- Issue: Test 5 ("DAG disabled — fallback note") asserts
  `grep -q "No milestones found\|dependency tracking requires"`. The string
  "dependency tracking requires MILESTONE_DAG_ENABLED=true" is emitted only by
  `_render_progress_inline` (milestone_progress_helpers.sh:157) when
  `parse_milestones_auto` returns non-empty data. Since there is no CLAUDE.md in
  TMPDIR, `parse_milestones_auto` always returns empty, causing the early-exit
  "No milestones found" branch to fire instead. The OR-condition means the test
  passes without ever showing the "dependency tracking requires" message. The
  test confirms the function does not crash when DAG is disabled, which has
  value, but the advertised "fallback note" behavior is never exercised.
- Severity: MEDIUM
- Action: Add a fixture that seeds a CLAUDE.md in TMPDIR containing inline
  milestone entries, then call `_render_milestone_progress` with
  `MILESTONE_DAG_ENABLED=false` and assert the output contains "dependency
  tracking requires". Keep the existing test for the no-milestones variant.

#### COVERAGE: Untested decision branch in _compute_next_action (milestone mode, not complete)
- File: tests/test_next_action_computation.sh (no matching test)
- Issue: `_compute_next_action` has a distinct code path at
  milestone_progress.sh:93-96: when `_PIPELINE_EXIT_CODE=0` AND
  `MILESTONE_MODE=true` AND `_CACHED_DISPOSITION` is neither
  `COMPLETE_AND_CONTINUE` nor `COMPLETE_AND_WAIT` (pipeline ran in milestone
  mode but the coder did not reach a completion disposition). The implementation
  falls through to `echo "Run tekhton --status to review pipeline state."` —
  the same text as the non-milestone success path — but via a structurally
  separate branch that is not covered by any of the eight tests. Tests 1 and 2
  set `COMPLETE_AND_CONTINUE`; Test 3 uses `MILESTONE_MODE=false`. No test
  sets `MILESTONE_MODE=true` with an empty or non-completion disposition.
- Severity: MEDIUM
- Action: Add a test: `_PIPELINE_EXIT_CODE=0`, `MILESTONE_MODE=true`,
  `_CACHED_DISPOSITION=""`. Verify output contains "tekhton --status". This
  guards against unintended behavioral divergence if the branch is later
  specialized.

#### NAMING: Test labels missing expected outcome in test_next_action_computation.sh
- File: tests/test_next_action_computation.sh:154, :178
- Issue: Test 6 is labelled "Test 6: failure + API error" and Test 8 is labelled
  "Test 8: failure + generic". Neither encodes the expected outcome, making
  failure messages less informative. Compare Test 7: "failure + stuck/timeout →
  --diagnose root cause", which states both stimulus and response.
- Severity: LOW
- Action: Rename to "failure + API error → re-run message" and
  "failure + generic → --diagnose" respectively.

#### NAMING: Test labels missing expected outcome in test_diagnose_recovery_command.sh
- File: tests/test_diagnose_recovery_command.sh:94, :105
- Issue: Test 3 "Coder stage" and Test 4 "Tester stage" omit the expected
  outcome. All other tests in this file include the expected result in the label
  (e.g. "Reviewer stage maps to review", "No milestone → no --milestone flag").
- Severity: LOW
- Action: Rename to "Coder stage → --start-at coder" and
  "Tester stage → --start-at tester".

#### COVERAGE: --all and --deps flags never exercised simultaneously
- File: tests/test_milestone_progress_display.sh (no matching test)
- Issue: Tests 3 and 4 verify `--all` and `--deps` individually but no test
  passes both flags together. `_render_progress_dag` processes them as
  independent booleans: `show_all` controls whether the Done section is printed,
  `show_deps` controls whether the "depends:" sub-line is printed per milestone.
  The combined rendering path is structurally distinct.
- Severity: LOW
- Action: Add a test passing `--all --deps` against a mixed manifest and
  asserting both a completed milestone title and a "depends:" line appear in
  the same output.

### None (INTEGRITY, WEAKENING, SCOPE, EXERCISE, ISOLATION)
No violations found in any of these categories.

All three test files create fixtures exclusively inside a `mktemp -d` TMPDIR
with `trap 'rm -rf "$TMPDIR"' EXIT`. No test reads from `.tekhton/`,
`.claude/logs/`, pipeline run artifacts, or any other mutable project path.
`BUILD_ERRORS_FILE`, `PIPELINE_STATE_FILE`, and `MILESTONE_STATE_FILE` are all
pointed at paths inside TMPDIR.

All expected values are traceable to implementation logic: "3 done / 5 total
(60%)" derives from 3 done rows out of 5 in the test manifest (3×100/5=60);
"tekhton --start-at review" traces to the `reviewer) start_at="review" ;;`
case in `_diagnose_recovery_command`; "re-run when API is available" traces
verbatim to the `UPSTREAM` branch in `_compute_next_action`.

All implementation functions under test (`_render_milestone_progress`,
`_compute_next_action`, `_diagnose_recovery_command`) are called with real
source files — no core logic is mocked away. Only `run_build_gate` is stubbed
to prevent gate side-effects during library sourcing, which is appropriate.

All three test files are new (no modifications to existing tests), so no
weakening check applies. All referenced functions exist at the expected paths in
the implementation. Assertion counts match the tester's reported total of 26
(test_milestone_progress_display.sh: 9, test_next_action_computation.sh: 8,
test_diagnose_recovery_command.sh: 9).
