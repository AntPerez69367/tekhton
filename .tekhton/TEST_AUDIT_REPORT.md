## Test Audit Report

### Audit Summary
Tests audited: 4 files, 16 test functions
Verdict: PASS

### Findings

#### SCOPE: test_orchestrate_helpers_milestone_count does not exercise the fixed call site
- File: tests/test_orchestrate_helpers_milestone_count.sh:49–77
- Issue: Note 3's fix changed `get_milestone_count "CLAUDE.md"` to
  `get_milestone_count "${PROJECT_RULES_FILE:-CLAUDE.md}"` at
  `lib/orchestrate_helpers.sh:39`. The test sources `milestones.sh` and calls
  `get_milestone_count` directly — it never sources `orchestrate_helpers.sh` and
  never exercises the fixed call site. `test_milestone_count_custom_rules_file`
  manually interpolates `${PROJECT_RULES_FILE:-CLAUDE.md}` itself, verifying
  only that the function accepts a custom path, not that `orchestrate_helpers.sh:39`
  passes the right argument. A typo reintroducing the hardcoded literal there
  would not be caught.
- Severity: MEDIUM
- Action: Add a grep assertion confirming `lib/orchestrate_helpers.sh` contains
  `get_milestone_count "${PROJECT_RULES_FILE` at the relevant line (matching the
  pattern used in `test_review_effective_coder_turns.sh`), or source
  `orchestrate_helpers.sh`, stub its collaborators, and invoke
  `_run_auto_advance_chain` with `PROJECT_RULES_FILE` pointing to a custom file.

#### EXERCISE: test_review_effective_coder_turns uses static grep rather than code execution
- File: tests/test_review_effective_coder_turns.sh:13–64
- Issue: All three test functions are static grep checks on the live source file
  `stages/review.sh`. No code is invoked — there is no `run_agent` call and no
  observable runtime output. The tests confirm the fix is textually present but
  cannot detect regressions in how the variable is actually consumed.
  `test_review_jr_coder_escalation` (lines 28–43) compares an
  `EFFECTIVE_JR_CODER_MAX_TURNS` grep count against a `"Jr Coder` grep count;
  the two patterns target different line types so any quoting-style divergence
  silently under-counts one side.
- Severity: MEDIUM
- Action: These tests are acceptable as change-verification snapshots. Supplement
  with at least one test that stubs `run_agent`, sets `EFFECTIVE_CODER_MAX_TURNS`,
  and confirms the argument passed to `run_agent` reflects the escalated value.

#### ISOLATION: cd without subshell in test_orchestrate_helpers_milestone_count
- File: tests/test_orchestrate_helpers_milestone_count.sh:43–44, 74–75, 117–118
- Issue: Each test function calls `cd "$PROJECT_DIR"` then `cd - > /dev/null`.
  The `cd -` does not execute when the function returns early on assertion
  failure (e.g., lines 39–41, 71–73, 113–115). Under `set -euo pipefail` the
  script exits immediately so subsequent tests are not reached, but any future
  refactor relaxing that would leave the harness in the wrong directory.
- Severity: LOW
- Action: Wrap each function body in a subshell `( ... )` so `cd` never escapes,
  or use `pushd`/`popd` with a `trap`.

#### EXERCISE: Opaque exit-code capture for NEEDS_WORK in test_audit_verdict_unknown_catch_all
- File: tests/test_audit_verdict_unknown_catch_all.sh:104–105
- Issue: The two-line pattern:
    `output=$(_route_audit_verdict "$verdict" 2>&1) || exit_code=$?`
    `[[ -z "${exit_code:-}" ]] && exit_code=$?`
  is functionally correct but relies on a coincidence: when `exit_code="1"`,
  `[[ -z "1" ]]` returns 1, the `&&` short-circuits, and `exit_code` is not
  overwritten. Line 2 captures the exit code of the `[[` expression, not of
  `_route_audit_verdict`. No assertion honesty violation — the expected value
  (1) is derived from the implementation's documented `return 1` for NEEDS_WORK.
- Severity: LOW
- Action: Replace with an explicit pattern:
    `set +e; _route_audit_verdict "$verdict" >/dev/null 2>&1; exit_code=$?; set -e`

#### None: test_escalate_turn_budget_shell_fallback
- File: tests/test_escalate_turn_budget_shell_fallback.sh
- Issue: None. All seven test functions verify arithmetic directly derivable from
  the implementation formula `_base + (_base * _factor_x100 * _count) / 100`.
  Factors 1.5, 1.2, 1.75, 2.0, 2 (integer), and "invalid" all match the
  implementation paths exactly. The cap-clamp test correctly uses 200 as both
  cap argument and expected value. The fake-awk mechanism reliably forces the
  shell fallback branch. Isolation is good — all tests run in a subshell with a
  controlled fake `awk` binary.
- Severity: N/A
- Action: None.
