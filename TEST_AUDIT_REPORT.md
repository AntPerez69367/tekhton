## Test Audit Report

### Audit Summary
Tests audited: 1 file, 2 new test functions (plus 12 pre-existing functions unchanged)
Verdict: CONCERNS

### Findings

#### INTEGRITY: Unconditional pass() in empty-artifact test
- File: tests/test_artifact_handler_ops.sh:527
- Issue: `pass "_merge_artifact_group skips merge gracefully for empty artifact"` fires
  unconditionally after calling `_merge_artifact_group`. The stated intent is that
  MERGE_CONTEXT.md was NOT created (because no readable files exist in the empty
  `.cursor/` directory), but that state is never asserted. Any execution that does not
  crash — including one that silently wrote content to MERGE_CONTEXT.md — records a
  pass. This is equivalent to `assertTrue(True)`.
- Severity: HIGH
- Action: Replace the unconditional pass() with an explicit assertion:
  ```bash
  if [[ ! -f "${MERGE_EMPTY_PROJ}/MERGE_CONTEXT.md" ]]; then
      pass "_merge_artifact_group skips merge gracefully for empty artifact"
  else
      fail "_merge_artifact_group should NOT create MERGE_CONTEXT.md for empty artifact"
  fi
  ```

#### EXERCISE: Lazy-load guard test depends on real prompts.sh and template file
- File: tests/test_artifact_handler_ops.sh:460-507
- Issue: The guard test correctly mocks `_call_planning_batch` but relies on the real
  `prompts.sh` being sourced via the guard at `artifact_handler_ops.sh:108-111`, and
  on `prompts/artifact_merge.prompt.md` existing and being renderable. If either is
  missing or has unmet transitive dependencies, the test fails for a reason unrelated
  to the guard itself. The mock at lines 470-481 gates its output on `$_prompt` being
  non-empty, which requires `render_prompt "artifact_merge"` to succeed end-to-end.
- Severity: MEDIUM
- Action: Add a `render_prompt` stub before `_call_planning_batch` to isolate the guard
  test from template loading concerns:
  ```bash
  render_prompt() { echo "STUBBED_PROMPT_FOR_$1"; }
  ```
  Undefine it with `unset -f render_prompt` after the test group. This decouples
  "guard loads prompts.sh when needed" from "render_prompt works end-to-end."

#### COVERAGE: Guard precondition is assumed but not verified
- File: tests/test_artifact_handler_ops.sh:484
- Issue: The comment at line 484 states "WITHOUT having sourced prompts.sh beforehand"
  but the test never asserts this precondition. If an earlier test or a transitively
  sourced library defined `render_prompt`, the guard would not fire and the test would
  still pass — proving only that `_merge_artifact_group` works with `render_prompt`
  already available, not that the guard itself loaded it.
- Severity: LOW
- Action: Add an explicit precondition check at the start of the test group:
  ```bash
  if type render_prompt &>/dev/null; then
      fail "Precondition: render_prompt already defined before lazy-load guard test"
  fi
  ```

#### COVERAGE: No test for guard failure path (prompts.sh unreachable)
- File: tests/test_artifact_handler_ops.sh (new test block)
- Issue: There is no test covering the case where the `source "${_ops_dir}/prompts.sh"`
  call in the guard fails (e.g., prompts.sh not found in a non-standard install layout).
  Under `set -euo pipefail` in the implementation, a failed source aborts the function
  with an error. This failure mode exists and is untested.
- Severity: LOW
- Action: Consider a negative test that mocks or redirects `_ops_dir` to a path without
  prompts.sh, then verifies `_merge_artifact_group` exits non-zero and writes no partial
  output to MERGE_CONTEXT.md.
