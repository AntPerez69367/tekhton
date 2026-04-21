## Test Audit Report

### Audit Summary
Tests audited: 1 file, 49 test cases (script-style)
  - `tests/test_pipeline_order_policy.sh` — 49 assertions across 4 function groups
Verdict: PASS

### Findings

#### ISOLATION: DOCS_AGENT_ENABLED leaks from test group 6 into tests 7–12
- File: tests/test_pipeline_order_policy.sh:249
- Issue: `export DOCS_AGENT_ENABLED="true"` is set in the "docs enabled" test case (line 249)
  and never reset before tests 8–12 (FORCE_AUDIT, drift observation, drift runs-since, test_first
  order, wrap-up-last). All six downstream tests execute with an unintended
  `DOCS_AGENT_ENABLED=true`, meaning `get_run_stage_plan` inserts a "docs" stage into the
  planned output that the tests do not expect. None of the tests actually fail because tests 8–12
  use loose `=~` substring assertions that tolerate the extra "docs" stage, but the fixture state
  does not match the documented defaults those tests claim to exercise. If the docs insertion logic
  regressed, tests 8–12 would still pass.
- Severity: MEDIUM
- Action: Add `export DOCS_AGENT_ENABLED="false"` after the SKIP_DOCS test (line 265) before the
  FORCE_AUDIT group begins. No implementation changes required.

#### COVERAGE: Tests 8–12 use weak substring assertions instead of exact stage plan checks
- File: tests/test_pipeline_order_policy.sh:271–317
- Issue: Tests 1–7 correctly assert exact full stage plan strings
  (e.g., `[[ "$result" == "preflight intake coder security review tester wrap-up" ]]`).
  Tests 8–12 switch to `=~` regex checks: `[[ "$result" =~ architect ]]`,
  `[[ "$result" =~ "tester-write" ]]`, `[[ "$result" =~ "wrap-up"$ ]]`. These loose assertions
  cannot detect extra or missing stages, wrong stage ordering, or duplicate entries. Specifically:
  test 11 (test_first order) only confirms "tester-write" is present somewhere in the output —
  it does not verify that tester-write precedes coder, which is the defining property of
  test_first order.
- Severity: MEDIUM
- Action: Replace `=~` assertions in tests 8–12 with exact equality checks against the full
  expected stage plan string. Resolving the DOCS_AGENT_ENABLED leakage (above) is a prerequisite
  so the expected strings can be stated accurately.

#### COVERAGE: No below-threshold boundary tests for drift triggers
- File: tests/test_pipeline_order_policy.sh:277–297
- Issue: Tests 9 and 10 verify drift triggers fire when DRIFT_OBSERVATION_COUNT >= threshold and
  DRIFT_RUNS_SINCE_AUDIT >= threshold, respectively. There is no complementary test that architect
  is NOT included when counts are one below the threshold. The implementation uses `(( _drift_obs
  >= _drift_thr ))` — an off-by-one regression (e.g., `>` instead of `>=`) would not be caught.
- Severity: LOW
- Action: Add test cases with DRIFT_OBSERVATION_COUNT=7/DRIFT_OBSERVATION_THRESHOLD=8 and
  DRIFT_RUNS_SINCE_AUDIT=4/DRIFT_RUNS_SINCE_AUDIT_THRESHOLD=5 asserting that architect does NOT
  appear in the stage plan output.

### Scope Alignment Notes (freshness sample)
- tests/test_detect_project_type.sh: Sources lib/detect.sh and lib/detect_commands.sh, neither
  modified this run. No orphan or scope issues.
- tests/test_detect_report.sh: Sources lib/detect_report.sh, not modified this run. No issues.
- tests/test_detect_ui_framework.sh: Not read (outside modified-file set). The coder did not
  touch UI framework detection logic.

### Implementation Verification
All 49 assertions in tests/test_pipeline_order_policy.sh were cross-verified against
lib/pipeline_order_policy.sh and lib/pipeline_order.sh:

- get_stage_metrics_key (tests 1–17): All 16 alias mappings verified against the case branches
  at pipeline_order_policy.sh:25–33. Empty input fallback verified against the `*)` branch which
  delegates to get_stage_display_label (pipeline_order.sh:216–234), returning "" for empty input.
- get_stage_array_key (tests 18–23): All 6 cases verified against pipeline_order_policy.sh:47–54.
- get_stage_policy (tests 24–38): All 14 policy records verified against the case table at
  pipeline_order_policy.sh:68–83. The "reviewer" resolution test (line 179) correctly exercises
  the get_stage_metrics_key indirection path ("reviewer" → "review" → pipeline class).
- get_run_stage_plan (tests 39–49): All 12 test scenarios traced through the implementation at
  pipeline_order_policy.sh:98–132. Expected outputs for tests 1–7 (exact equality checks) are
  correct. Tests 8–12 produce correct actual results but weak assertions do not fully protect
  stage ordering or completeness.

No tautologies, hard-coded magic values, or assertions that always pass were found. The
implementation is exercised directly — no mocking.
