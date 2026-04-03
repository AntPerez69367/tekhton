## Planned Tests
- [x] `tests/test_build_errors_phase2_header.sh` — verify BUILD_ERRORS.md header when Phase 2 fails after Phase 1 passes
- [x] `tests/test_classify_errors_dedup.sh` — verify classify_build_errors_all deduplicates multiple unmatched lines
- [x] `tests/test_file_size_ceilings.sh` — verify gates.sh, error_patterns.sh, errors.sh all under 300-line ceiling

## Test Run Results
Passed: 2  Failed: 1

## Bugs Found
- BUG: [lib/gates.sh:170] Phase 2 header fix ineffective — file existence check is inside the append redirect block (>>), so bash opens the file before evaluating the condition. The check `[[ ! -f BUILD_ERRORS.md ]]` always finds the file exists, preventing the canonical header from being written when Phase 1 passes and Phase 2 (compile) fails alone. Correct fix: move the condition outside the redirect block.

## Files Modified
- [x] `tests/test_build_errors_phase2_header.sh`
- [x] `tests/test_classify_errors_dedup.sh`
- [x] `tests/test_file_size_ceilings.sh`
