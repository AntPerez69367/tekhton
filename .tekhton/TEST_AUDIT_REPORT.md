## Test Audit Report

### Audit Summary
Tests audited: 3 files, 49 test functions
(18 shell tests in test_run_op_lifecycle.sh; 20 Python tests in test_tui.py
including the rewritten test_timings_panel_working_row; 11 Python tests in
test_tui_render_timings.py including TestSubstageBreadcrumb)
Verdict: PASS

### Findings

#### WEAKENING: Net-minus-one assertion count in test_run_op_lifecycle.sh
- File: tests/test_run_op_lifecycle.sh:149–161 (Test 6)
- Issue: The shell-based weakening detector reports "net loss of 1 assertion(s)
  (removed 1, added 00)". Cross-referencing the implementation confirms this is
  a counting artifact, not a real coverage gap. The old current_operation
  presence assertion was retired along with the field itself; Test 6 replaces it
  with an absence assertion using the form
  `python3 -c "... sys.exit(0 if 'current_operation' not in d else 1)"`.
  That inverted form does not match the detector's assertion-add pattern,
  producing the apparent net loss. Functional coverage is richer in the rewrite:
  field absence is verified (Test 6), substage label presence during execution
  (Test 7), and substage label clearance on both success (Test 12) and failure
  (Test 15) are new additions with no prior equivalents.
- Severity: LOW
- Action: No test change required. The TESTER_REPORT already explains the
  inversion. Optionally note in the detector that negated exit-code assertions
  count as positive assertions.

#### WEAKENING: test_substage_ignored_in_working_state removed from test_tui_render_timings.py
- File: tools/tests/test_tui_render_timings.py (removed function)
- Issue: The detection flag is technically accurate — one test function was
  removed. However, the removal is correct. The deleted test asserted that
  working state ignored substage labels, which was the pre-M115 behavior.
  M115 changed this: tui_render_timings.py:88–90 now renders the breadcrumb for
  both "running" and "working" states. Retaining the old test would assert
  incorrect behavior against the current implementation.
  The replacement test_substage_breadcrumb_in_working_state (line 456) verifies
  the new behavior and adds a turns-column blanking invariant
  (assert "--/50" not in panel_str) that the removed test did not cover, making
  the replacement strictly more thorough.
- Severity: LOW
- Action: No change required. Removal is a correct behavioral update.

#### SCOPE: All STALE-SYM flags are false positives
- File: tests/test_run_op_lifecycle.sh, tools/tests/test_tui.py,
  tools/tests/test_tui_render_timings.py
- Issue: Every flagged symbol (echo, cat, grep, jobs, wc, json, sys, pathlib,
  pytest, Console, Panel, Table, etc.) is either a POSIX shell built-in or a
  Python standard-library/third-party import. The orphan detector does not
  recognize these as valid without a project-file definition. No real orphaned
  tests exist: all imports resolve at runtime and all shell references are
  interpreter built-ins.
- Severity: LOW
- Action: No test changes required. Consider scoping the orphan detector to
  exclude known built-ins and stdlib modules to reduce false-positive noise.

#### COVERAGE: Heartbeat liveness not verified during execution
- File: tests/test_run_op_lifecycle.sh:304–316 (Test 16)
- Issue: Test 16 verifies that no background jobs remain after run_op returns,
  but there is no assertion that the heartbeat subprocess IS running while the
  wrapped command executes. The heartbeat is the mechanism that prevents the
  TUI watchdog from firing during long commands (the stated purpose at
  tui_ops.sh:118–126). A test that checks kill -0 $hb_pid inside the wrapped
  command would provide positive liveness coverage rather than only cleanup
  coverage.
- Severity: LOW
- Action: Optional enhancement — not required for PASS verdict. Could add a test
  where the wrapped command runs `jobs -r | wc -l` and asserts the count is 1.

### Notes on Assertion Honesty

All concrete values verified against implementation:
- Test 7: "Running test baseline" is the literal label passed to run_op. ✓
- Test 9: "coder" matches _TUI_CURRENT_STAGE_LABEL set immediately before the
  call; run_op in tui_ops.sh:107–142 never mutates _TUI_CURRENT_STAGE_LABEL. ✓
- Test 10: stages_count == "0" is correct; run_op calls tui_substage_begin/end,
  never tui_finish_stage, so _TUI_STAGES_COMPLETE is never appended to. ✓
- test_timings_panel_working_row: "running lint checks", "coder", "»" derive
  from the status dict in the test; "--/40" absence is correct because
  tui_render_timings.py:102–105 sets live_turns="" for working state. ✓
- TestNormalizeTime: "1m30s" for "90s", "1m23s" for "83s", "1h2m5s" for "3725s"
  all match _fmt_duration arithmetic in tui_render_common. ✓

### Implementation–Test Alignment Spot-Check

| Assertion | Implementation location | Match |
|---|---|---|
| current_operation absent in JSON | tui_helpers.sh:196–227 (field not emitted) | ✓ |
| current_substage_label=label during exec | tui_ops.sh:115 tui_substage_begin call | ✓ |
| stage_label unchanged by run_op | tui_ops.sh:107–142 (never touches _TUI_CURRENT_STAGE_LABEL) | ✓ |
| stages_complete not appended | tui_ops.sh:107–142 (calls substage API, not tui_finish_stage) | ✓ |
| working state renders breadcrumb | tui_render_timings.py:88–90 | ✓ |
| working state blanks turns column | tui_render_timings.py:102–105 | ✓ |
| _empty_status has no current_operation | tui.py:63–86 | ✓ |
| _build_working_bar breadcrumb from current_substage_label | tui_render.py:83–104 | ✓ |

### Rubric Detail

**1. Assertion Honesty — PASS**
No hard-coded magic values unconnected to implementation logic. Every expected
value is either the literal label passed to the function under test, a known
field absence verified against the retired implementation, or a mathematical
output of _fmt_duration for specific inputs.

**2. Edge Case Coverage — PASS with noted LOW gap**
Success and failure paths both covered (Tests 3/4/13/14). TUI active and inactive
paths both covered. Label-not-forwarded (Test 2), stages_complete not appended
(Test 10), parent stage preserved (Test 9), and backward-compatibility (missing
substage keys tolerated) are all exercised. The only LOW gap is heartbeat
liveness during execution (see COVERAGE finding above).

**3. Implementation Exercise — PASS**
test_run_op_lifecycle.sh sources the real lib/tui.sh (and transitively
tui_ops.sh and tui_helpers.sh). Python tests call real _build_timings_panel and
_build_working_bar on real Rich renderable output. The only stubs are log/warn/
error helpers (appropriate noise suppression) and color variables.

**4. Test Weakening Detection — LOW (both explained)**
See WEAKENING findings above. Neither represents a genuine coverage regression.

**5. Test Naming and Intent — PASS**
Shell tests: section headers (=== Test N: ... ===) and pass() messages encode
the scenario and expected outcome. Python tests: class and method names are
descriptive (TestSubstageBreadcrumb.test_substage_breadcrumb_in_working_state,
test_missing_substage_keys_tolerated, etc.).

**6. Scope Alignment — PASS**
No references to the retired _TUI_OPERATION_LABEL global or current_operation
JSON field in any assertion (Test 6 verifies absence, which is correct).
All sourced libraries and imported modules exist in the current repository.

**7. Test Isolation — PASS**
test_run_op_lifecycle.sh: TMPDIR_TEST=$(mktemp -d) with trap cleanup; all
status file paths are set to paths under this temp dir. Python tests: all use
in-memory dicts or pytest's tmp_path fixture. No test reads mutable project
state files (.tekhton/, .claude/logs/, etc.) without fixture isolation.
