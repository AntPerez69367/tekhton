## Planned Tests
- [x] `tests/test_validate_config_design_file.sh` — DESIGN_FILE empty string and trailing slash branches
- [x] `tests/test_common_box_edge_cases.sh` — Box-drawing UTF-8 vs ASCII fallback and wide content
- [x] Fix existing test files with non-blocking issues
- [x] Extract `_extract_retry_after_seconds` to shared helper

## Test Run Results
Passed: 102  Failed: 0

### Details
- test_validate_config_design_file.sh: 8 passed
- test_common_box_edge_cases.sh: 11 passed
- test_draft_milestones_validate_lint.sh: 6 passed
- test_ensure_gitignore_entries.sh: 8 passed
- test_quota.sh: 74 passed
- test_quota_retry_after_integration.sh: 7 passed

## Bugs Found
None

## Files Modified
- [x] `tests/test_validate_config_design_file.sh` (new)
- [x] `tests/test_common_box_edge_cases.sh` (new)
- [x] `tests/test_draft_milestones_validate_lint.sh`
- [x] `tests/test_ensure_gitignore_entries.sh`
- [x] `tests/test_quota.sh`
- [x] `tests/test_quota_retry_after_integration.sh`

## Summary of Changes

### Coverage Gaps Addressed (2 new test files)

1. **test_validate_config_design_file.sh** — Tests lib/validate_config.sh checks 6a and 6b
   - Check 6a: Detects empty DESIGN_FILE string in pipeline.conf
   - Check 6b: Detects DESIGN_FILE ending in '/' (directory vs file)
   - Check 7: File existence validation for DESIGN_FILE
   - Integration tests for grep patterns in pipeline.conf

2. **test_common_box_edge_cases.sh** — Tests lib/common_box.sh edge cases
   - UTF-8 terminal detection with LANG and LC_ALL variables
   - ASCII fallback box characters (+, -, |) when UTF-8 unavailable
   - Box-drawing characters (╔, ╗, ╚, ╝, ═, ║) when UTF-8 detected
   - Horizontal line building with various widths
   - Box line printing with padding calculations
   - Box frame rendering with single and multiple lines
   - report_error() structure and output
   - Wide/special character handling

### Non-Blocking Notes Resolved (4 files fixed)

1. **test_ensure_gitignore_entries.sh:70** — Updated comment and array
   - Added missing `.claude/tui_sidecar.pid` entry to EXPECTED_ENTRIES
   - Updated comment from "All 17" to "All 18" to match common.sh

2. **test_draft_milestones_validate_lint.sh:12** — Fixed TMPDIR shadowing
   - Changed `TMPDIR=$(mktemp -d)` to `TEST_TMPDIR=$(mktemp -d)`
   - Updated all references to use TEST_TMPDIR instead of shadowing standard env var

3. **test_quota.sh:413-434** — Extracted function to shared helper
   - Removed inline definition of `_extract_retry_after_seconds`
   - Now sources `tests/helpers/retry_after_extract.sh`
   - Eliminates drift risk between inline copies

4. **test_quota_retry_after_integration.sh:53-75** — Extracted function to shared helper
   - Removed inline definition of `_extract_retry_after_seconds`
   - Now sources `tests/helpers/retry_after_extract.sh`
   - Eliminates drift risk between inline copies

### Test Results
- All 102 new/modified test assertions pass
- No bugs detected in implementation
- Shared helper properly extracted to reduce maintenance burden

## Out-of-Scope Items

The following 11 non-blocking notes from NON_BLOCKING_LOG.md are **out of scope** for
the test coverage agent and were not addressed (these require implementation review,
documentation fixes, or architectural decisions):

1. `lib/tui_helpers.sh:70-75` — Comment clarity about legacy detection defensive pattern
2. `lib/common.sh` — 445 lines over 300-line ceiling (pre-existing architectural)
3. `_classify_project_maturity` — Redundant disk-file checks (code cleanup)
4. `tests/test_m84_static_analysis.sh` — Comment says "still excludes common.sh" (documentation)
5. `lib/validate_config.sh:138` — Comment numbering misleading (check 6 vs 7)
6. `lib/replan_brownfield.sh` — 347 lines over 300-line ceiling (pre-existing architectural)
7. `stages/plan_generate.sh:123` — Unchecked write to CLAUDE.md (code hardening)
8. `lib/indexer_helpers.sh` — Missing `_indexer_emit_stderr_tail()` from header comment
9. `lib/tui_ops.sh:165` — Comment doesn't name preserved globals (documentation)
10. `lib/tui_ops.sh:180` — Silent path protocol difference in substage closure (code clarity)
11. `lib/milestone_split_dag.sh:81,87` — Defensive `..` rejection and printf vs echo (security)
12. `CODER_SUMMARY` — Prose mentions "four scenarios" but file has three fixtures (documentation)

These items involve implementation code review, documentation updates, or architectural
decisions and are outside the scope of test coverage validation.
