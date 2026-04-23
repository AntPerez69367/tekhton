## Test Audit Report

### Audit Summary
Tests audited: 2 files, 27 test assertions
- `tests/test_milestone_acceptance_lint.sh` — 21 assertions (unit + integration)
- `tests/test_draft_milestones_validate_lint.sh` — 6 assertions (authoring-time integration)

Verdict: PASS

### Findings

#### WEAKENING: Integration block inverted with net assertion loss
- File: tests/test_milestone_acceptance_lint.sh:131-209
- Issue: The shell-detected weakening is real but justified. Three assertions were
  removed (lint appears in acceptance output; ≥N warnings; NON_BLOCKING_LOG written)
  and two were added (lint does NOT appear; NON_BLOCKING_LOG not written). Net: −1
  assertion in this block. The weakening tool reports "added 00" — this count is
  incorrect; manual inspection confirms 2 new pass()/fail() pairs at lines 199–208.
  The inversion is the correct response to the feature change (lint moved from
  acceptance gate to authoring time). The 6 new assertions in
  test_draft_milestones_validate_lint.sh cover the positive behavior at the new call
  site, so aggregate coverage increased. The tester report explicitly documents the
  rationale.
- Severity: MEDIUM
- Action: Add a one-line comment above the integration block (line 131) noting the
  intentional inversion, e.g., "Assertions inverted: lint moved to authoring time;
  these guard against regression back into the acceptance gate." This makes the
  direction change self-documenting and prevents a future reader from "correcting"
  the negated assertions back to positive.

#### INTEGRITY: NON_BLOCKING_LOG assertion is trivially true
- File: tests/test_milestone_acceptance_lint.sh:205-208
- Issue: The assertion checks that check_milestone_acceptance() does not write
  "Lint:" to NON_BLOCKING_LOG_FILE. lib/milestone_acceptance.sh contains zero
  references to NON_BLOCKING_LOG_FILE — the function has no write path to that file.
  Confirmed: grep for NON_BLOCKING_LOG in lib/milestone_acceptance*.sh returns no
  matches. The assertion therefore always passes regardless of what the function
  does. As a regression guard it is weak; it cannot detect a regression unless the
  regression simultaneously re-introduces both a lint call and a NON_BLOCKING_LOG
  write in the acceptance gate.
- Severity: LOW
- Action: Either remove the NON_BLOCKING_LOG check as redundant (the stdout check
  at lines 199-202 is sufficient to catch lint appearing in acceptance output), or
  strengthen it by verifying that the file remains clean even when a
  lint-triggering milestone is processed, while a spy/hook is in place that would
  detect any write to the file path.

#### SCOPE: False-positive loop reads live project milestone files
- File: tests/test_milestone_acceptance_lint.sh:114-129
- Issue: The loop iterates over m73-m83 milestone files in
  ${TEKHTON_HOME}/.claude/milestones/. All 11 files are present as of this run, but
  they are project-lifecycle files: future archival (removing them from
  .claude/milestones/) would cause the loop to fire fail "M${mnum}: milestone file
  not found" for any missing entry, failing the test for reasons unrelated to lint
  behavior. This is pre-existing code, not introduced in this run.
- Severity: LOW
- Action: Convert the false-positive check to use a small set of synthetic
  milestone fixtures in TMPDIR that are verified to contain no spurious lint
  triggers. This decouples the test from the project's archival lifecycle. If
  retaining real-file coverage is preferred, replace the hard fail with a skip-if-
  missing guard ([[ -f "$mfile" ]] || { pass "M${mnum}: file archived, skipping";
  continue; }) and document the intent.

### Additional Observations (no action required)

**STALE-SYM flags are all false positives.** Every flagged symbol in
tests/test_milestone_acceptance_lint.sh (break, cat, cd, continue, dirname, echo,
grep, mkdir, mktemp, pwd, return, set, source, trap, true) is a shell builtin or
standard utility. The shell symbol scanner does not model builtins. Ignore.

**Assertion honesty: PASS.** All assertions in both files derive from real function
calls (_lint_has_behavioral_criterion, _lint_refactor_has_completeness_check,
_lint_config_has_self_referential_check, lint_acceptance_criteria,
draft_milestones_validate_output) with non-trivial fixture inputs. No hard-coded
expected values unrelated to implementation logic were found.

**Test isolation: PASS.** Both test files create all run-specific state in TMPDIR
with an EXIT trap cleanup. The defensive bash -c subprocess in
test_draft_milestones_validate_lint.sh:170-188 correctly isolates the no-helper
scenario. No test reads mutable pipeline run artifacts (.tekhton/, .claude/logs/,
build reports, or pipeline state files). The false-positive milestone file loop is
the only non-isolated read, and it reads versioned source files (LOW severity,
noted above).

**test_draft_milestones_validate_lint.sh: PASS on all rubric criteria.** Fixtures
are synthetic, assertions are anchored to real function output ("LINT:", "behavioral",
"completeness"), the no-helper guard test exercises a real code path (declare -f
guard at draft_milestones_write.sh:85), and the clean-milestone negative test uses
criteria containing actual behavioral keywords that the implementation recognizes.
