## Planned Tests
- [x] `tests/test_stage_summary_model_display.sh` — Verify model name is included in STAGE_SUMMARY console output

## Test Run Results
Passed: 23  Failed: 0

### Test Coverage
The test file `test_stage_summary_model_display.sh` includes 9 comprehensive test sections with 23 assertions:
1. STAGE_SUMMARY format includes model name in correct parentheses format
2. Multiple stages show their respective models (Haiku, Sonnet, Opus)
3. _extract_stage_turns parser works with new format
4. Backward compatibility with old format (without model suffix)
5. Various Claude model version names are preserved correctly
6. Retry suffix handling with model name
7. Case-insensitive stage label matching in parser
8. Model name properly enclosed in parentheses with colon
9. Integration test: print_run_summary() displays model information

All tests verify the implementation matches the new format: `Label (model-name): turns, time`
The integration test confirms the complete end-to-end behavior where model information
is displayed when the run summary is printed to the console.

## Bugs Found
None

## Files Modified
- [x] `tests/test_stage_summary_model_display.sh`
