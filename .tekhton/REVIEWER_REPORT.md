# Reviewer Report

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `tests/test_draft_milestones_validate_lint.sh` tracks no PASS counter — only FAIL — so the final line is "All … tests passed." rather than an "N passed, 0 failed" count. Asymmetric from sibling test files (e.g. `test_milestone_acceptance_lint.sh`). No functional impact.
- CODER_SUMMARY states "four scenarios" for the new test file but the file has three test fixtures. Cosmetic discrepancy between the summary prose and the implementation; not a code defect.

## Coverage Gaps
- None

## Drift Observations
- None

---

## Review Notes

**Lint relocation (`lib/milestone_acceptance.sh` → `lib/draft_milestones_write.sh`):** Clean. The ~40-line lint block is entirely absent from `check_milestone_acceptance()` and a single comment replaces it with a pointer to the new call site. The acceptance gate is now exclusively pass/fail as intended.

**New call site in `draft_milestones_validate_output()`:** Correctly placed after the structural check returns clean (`errors -eq 0`). The `declare -f lint_acceptance_criteria &>/dev/null` guard makes the call safe in stripped-down test contexts. The `|| true` prevents lint failure from surfacing as a structural error. Lint output goes to stderr with a `LINT:` prefix and per-line indentation — appropriate for a non-blocking advisory.

**Test inversion (`test_milestone_acceptance_lint.sh`):** Git diff confirms only the assertions at the bottom changed (inverted). The scaffolding (TEKHTON_DIR usage, file creation) is unchanged from the pre-existing block, so no new environment dependencies were introduced.

**New test file (`test_draft_milestones_validate_lint.sh`):** Three fixture scenarios cover the contract: (1) structurally-valid-but-quality-weak milestone emits LINT: warnings and still returns 0, (2) behaviorally-rich milestone produces no warnings, (3) `declare -f` guard suppresses lint when the helper is not loaded. Each assertion is independently clear. All fixtures are structurally complete (≥5 AC items, all required sections), so no `set -e` hazard from the bare command-substitution assignments.

**`ARCHITECTURE.md`:** One-line update to `lib/milestone_acceptance_lint.sh` entry correctly documents the authoring-time call site.

**Line counts:** All modified files remain under the 300-line ceiling.
