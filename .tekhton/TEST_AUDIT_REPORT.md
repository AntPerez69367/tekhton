## Test Audit Report

### Audit Summary
Tests audited: 2 files, ~339 total assertions (14 in test_plan_docs_section.sh; remainder in test_plan_templates.sh)
Verdict: PASS

### Findings

#### ISOLATION: test_plan_docs_section.sh implicitly depends on DESIGN_FILE from test runner
- File: tests/test_plan_docs_section.sh:126,156
- Issue: `check_design_completeness` resolves `design_file` as `"${PROJECT_DIR}/${DESIGN_FILE:-}"`. The test sets `PROJECT_DIR` to a temp dir and writes `DESIGN.md` there, but never explicitly sets `DESIGN_FILE`. When run via `run_tests.sh`, `DESIGN_FILE="DESIGN.md"` is exported (run_tests.sh:36), so the path resolves correctly. When run standalone, `DESIGN_FILE` is unset → `design_file` becomes `"${TEST_TMPDIR}/"` (a directory, not a file) → `check_design_completeness` returns 1 for "file not found" (not "missing section") → `PLAN_INCOMPLETE_SECTIONS` stays empty → the assertion at line 132 ("Documentation Strategy should be listed as incomplete") FAILS. The test only works correctly when invoked through the test runner.
- Severity: MEDIUM
- Action: Add `export DESIGN_FILE="${DESIGN_FILE:-DESIGN.md}"` immediately after line 15 (`export PROJECT_DIR="$TEST_TMPDIR"`) so the test is self-contained when run standalone, consistent with how run_tests.sh already handles this variable.

#### COVERAGE: milestone_acceptance.sh DOCS_STRICT_MODE acceptance check has no test coverage
- File: tests/test_plan_docs_section.sh (absent)
- Issue: The new check 4 in `check_milestone_acceptance` (`lib/milestone_acceptance.sh:149–158`) — which blocks milestone completion when `DOCS_STRICT_MODE=true` and the reviewer flagged missing doc updates — has no test coverage. This is the most operationally significant behavioral change in M74 (a pipeline-blocking gate), and a regression there would be invisible to the test suite.
- Severity: LOW
- Action: Add test cases to `test_plan_docs_section.sh` that stub the relevant globals, create a fake reviewer report containing "Docs Updated missing", set `DOCS_STRICT_MODE=true`, source `milestone_acceptance.sh` helpers, and assert the blocking grep returns > 0. Also verify the check is skipped when `DOCS_STRICT_MODE=false`.

#### COVERAGE: grep -P (Perl regex) in test_plan_templates.sh is non-portable
- File: tests/test_plan_templates.sh:171
- Issue: `grep -oP '<!-- PHASE:\K[0-9]+'` uses PCRE syntax (`-P` flag + `\K` lookbehind). GNU grep on Linux supports this, but BSD/macOS grep does not. On macOS, the command silently produces empty output, `phases_found` is empty, and all 7 real-template PHASE-presence assertions (lines 172–176) would fail with misleading error messages. Since CLAUDE.md documents Linux as the target platform this is non-blocking in practice, but is a latent fragility.
- Severity: LOW
- Action: Replace with a POSIX-portable pipeline: `grep -o '<!-- PHASE:[0-9][0-9]* -->' "$tmpl" | grep -o '[0-9][0-9]*' | sort -u | tr '\n' ','`.

#### None (other rubric categories)
- Assertion Honesty: All assertions test real behavior. REQUIRED marker counts (cli-tool=11, web-app=10, api-service=10, mobile-app=10, web-game=11, custom=9, library=9) were verified against live `grep -c '<!-- REQUIRED -->'` output and match exactly. Config defaults (DOCS_ENFORCEMENT_ENABLED=true, DOCS_STRICT_MODE=false, DOCS_DIRS=docs/, DOCS_README_FILE=README.md) match lib/config_defaults.sh:412–415 exactly. No assertions use hard-coded values detached from implementation.
- Implementation Exercise: Tests call real implementations — `_extract_required_sections` and `check_design_completeness` from lib/plan_completeness.sh, `_extract_template_sections` from lib/plan_batch.sh (via plan.sh), config defaults from lib/config_defaults.sh — with non-trivial fixture inputs. No excessive mocking.
- Test Weakening: The REQUIRED marker count updates in test_plan_templates.sh (+1 per template) correctly reflect the new Documentation Strategy REQUIRED section added by M74. Prior counts are superseded, not weakened — the new values are strictly more accurate.
- Test Naming: Descriptive and scenario-plus-outcome throughout (e.g., "Documentation Strategy is REQUIRED", "DESIGN.md missing Documentation Strategy fails completeness", "DOCS_ENFORCEMENT_ENABLED defaults to true", "_extract_template_sections outputs 4-field format").
- Scope Alignment: All referenced symbols exist in the current codebase. `_extract_required_sections` is in lib/plan_completeness.sh; `_extract_template_sections` is in lib/plan_batch.sh (sourced via plan.sh); DOCS_* defaults are in lib/config_defaults.sh:412–415. No orphaned, stale, or renamed references detected.
- Test Isolation: test_plan_docs_section.sh creates `TEST_TMPDIR=$(mktemp -d)` and writes all DESIGN.md fixture content there; trap cleans up on exit. test_plan_templates.sh reads checked-in source files (templates, lib/*.sh) — not mutable runtime artifacts. Neither test reads .tekhton/ run artifacts.
