## Planned Tests
- [x] `tests/test_milestone_acceptance_lint.sh` — verify lint is NOT emitted from acceptance gate
- [x] `tests/test_draft_milestones_validate_lint.sh` — verify lint IS emitted from authoring-time validation

## Test Run Results
Passed: 27  Failed: 0

### Implementation Verification
✓ **Lint moved from acceptance gate to authoring time:**
  - `lib/milestone_acceptance.sh:28` — comment documents moved lint (no function call)
  - `lib/draft_milestones_write.sh:85-93` — lint called after structural validation passes

✓ **Non-blocking**: Lint warnings do not prevent validation from succeeding

✓ **Defensive guard**: `declare -f lint_acceptance_criteria &>/dev/null` ensures safety when helper not loaded

### Test Summary
- **test_milestone_acceptance_lint.sh**: 21 passed
  - Unit tests for lint helpers (_lint_has_behavioral_criterion, _lint_refactor_has_completeness_check, _lint_config_has_self_referential_check)
  - Integration test on real M72 milestone (triggers ≥2 warnings as expected)
  - False positive checks (M73-M83 verify no spurious warnings)
  - **KEY**: Integration test verifies lint is NOT emitted from check_milestone_acceptance()
  - **KEY**: Verifies NON_BLOCKING_LOG is not written to by acceptance gate

- **test_draft_milestones_validate_lint.sh**: 6 passed
  - Structural-only refactor passes validation (lint non-blocking)
  - LINT: prefix emitted for warnings during authoring
  - Behavioral criterion warning surfaces during authoring (actionable)
  - Refactor completeness warning surfaces during authoring (actionable)
  - Clean milestone (with behavioral criteria) produces no warnings
  - Lint gracefully skipped when helper not loaded (defensive)

## Bugs Found
None

## Files Modified
- [x] `tests/test_milestone_acceptance_lint.sh`
- [x] `tests/test_draft_milestones_validate_lint.sh`
