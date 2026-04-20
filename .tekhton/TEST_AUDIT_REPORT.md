## Test Audit Report

### Audit Summary
Tests audited: 1 file, 18 test functions
Verdict: CONCERNS

### Findings

#### EXERCISE: Background-cleanup assertion is always vacuous
- File: tests/test_run_op_lifecycle.sh:298
- Issue: `job_count=$(jobs -r | wc -l | tr -d ' ')` evaluates `jobs -r` inside a
  `$(...)` command substitution — a subshell that does not inherit the parent shell's
  job table. Additionally, non-interactive bash scripts do not enable job control, so
  `jobs -r` reports nothing regardless of live background processes. The assertion
  `[[ "$job_count" -eq 0 ]]` therefore always passes whether or not the heartbeat
  subprocess spawned by `run_op` was actually reaped. This is structurally equivalent
  to `assertTrue(True)` — the test comment says "heartbeat must be cleaned up" but the
  check cannot detect a leaked heartbeat under any condition.
- Severity: HIGH
- Action: Replace with a PID-based liveness check. Suggested approach: run
  `run_op "label" sleep 5` in a background subshell, read the status file to find
  the heartbeat via a short poll, then kill the subshell and assert the PID is gone
  via `kill -0 "$pid" 2>/dev/null && echo alive || echo dead`. A simpler alternative
  is to expose `_TUI_LAST_HB_PID` from `run_op` (set before the final `kill`) so the
  test can call `kill -0 "$_TUI_LAST_HB_PID" 2>/dev/null` after `run_op` returns and
  assert it fails (process is gone).

#### COVERAGE: No test for JSON-unsafe characters in the operation label
- File: tests/test_run_op_lifecycle.sh (suite-wide gap)
- Issue: All 18 tests use plain ASCII labels ("Running test baseline", "My Operation",
  "label"). The `_tui_json_build_status` function emits `current_operation` via
  `_tui_escape "$op_label"` → `_out_json_escape`. If a caller passes a label
  containing a double-quote, backslash, or newline (e.g., a path containing special
  chars), the emitted JSON could be malformed and crash the TUI renderer or silently
  corrupt state. No test exercises this boundary.
- Severity: MEDIUM
- Action: Add one test: set `_TUI_OPERATION_LABEL='label with "quotes" and \\slash'`,
  set `_TUI_AGENT_STATUS="working"`, call `_tui_json_build_status 0`, pipe to
  `python3 -c "import json,sys; json.load(sys.stdin)"`, and assert it exits 0
  (valid JSON). This exercises `tui_helpers.sh:192` via the escape path.

### None (all other rubric dimensions)

No INTEGRITY, ISOLATION, WEAKENING, SCOPE, or NAMING violations found.

---

### Detailed per-file assessment

#### tests/test_run_op_lifecycle.sh (new — 18 test cases)

**Assertion Honesty**: PASS for 17 of 18 tests. All assertions call real implementation
functions (`run_op`, `_tui_json_build_status`, `_tui_write_status` via `run_op`) and
compare against values derived from those calls. Expected strings ("hello world",
"count", "Running test baseline", "idle", "") all match what the implementation
actually sets/emits; no magic constants. Exception: Test 16 (see EXERCISE finding above).

**Edge Case Coverage**: ADEQUATE. Covers the failure exit-code preservation path
(tests 4 and 13–14), the empty-label / idle state boundary (test 8), the no-TUI
passthrough path (tests 1–5 and 18), and post-failure cleanup (tests 13–15). The
JSON-unsafe label boundary is the only material gap.

**Implementation Exercise**: PASS. Tests source the real `lib/tui.sh` (which sources
`lib/tui_ops.sh` containing the full `run_op` implementation). Test 18 sources
`lib/common.sh` alone in a subshell to exercise the stub. No dependency is mocked
that is itself the code under test.

**Test Weakening**: N/A — `test_run_op_lifecycle.sh` is a new file (untracked in git).
No existing tests were modified by the tester.

**Naming**: PASS. All 18 test descriptions encode the scenario and expected outcome
(e.g., "run_op: current_agent_status=idle in status file after failure",
"passthrough: label is consumed by run_op, not forwarded to command").

**Scope Alignment**: PASS. All referenced symbols (`run_op`, `_tui_json_build_status`,
`_tui_write_status`, `_TUI_OPERATION_LABEL`, `_TUI_AGENT_STATUS`) exist in the
modified implementation files (`lib/tui_ops.sh`, `lib/tui_helpers.sh`, `lib/tui.sh`,
`lib/common.sh`). `lib/output.sh` (sourced at line 39) exists.

**Isolation**: PASS. `TMPDIR_TEST=$(mktemp -d)` with `trap 'rm -rf "$TMPDIR_TEST"' EXIT`
covers all status file I/O. `_setup_tui_active()` reinitialises all `_TUI_*` globals
and deletes any prior status file before each active-TUI test case. No mutable pipeline
artifacts (`.tekhton/`, `.claude/logs/`) are read.
