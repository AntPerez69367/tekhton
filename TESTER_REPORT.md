## Planned Tests
- [x] `tests/test_metrics_total_time_computation.sh` — Verify total_time uses _STAGE_DURATION sum with TOTAL_TIME fallback
- [x] `tests/test_duration_estimation_jsonl.sh` — Test proportional duration estimation in JSONL parsing (both Python and shell paths)
- [x] `tests/test_duration_estimation_shell_fallback.sh` — Test shell fallback duration estimation with legacy metrics records

## Test Run Results
Passed: 24  Failed: 0

## Test Coverage Summary

### Test 1: total_time computation (6 tests)
- _STAGE_DURATION array sum takes precedence over TOTAL_TIME
- Fallback to TOTAL_TIME when _STAGE_DURATION is empty
- Partial stage durations with zero entries
- All stage durations zero → use TOTAL_TIME
- Large values (7200s) calculated correctly
- JSON format validation

### Test 2: Duration estimation — Python/JSON path (9 tests)
- Proportional estimation: duration = (total_time * stage_turns) / total_turns
- Actual durations used when provided (no estimation)
- Zero total turns edge case
- Mixed durations (some stages have durations, some don't)
- Asymmetric turns: many turns → short time, few turns → long time
- Large total_time (3600s) distributed proportionally
- Multiple metrics in JSONL processed independently

### Test 3: Duration estimation — Shell fallback path (9 tests)
- Identical test coverage to Test 2 using sed/awk extraction
- Confirms Python mocking forces shell path
- Validates portable extraction without Python dependency

## Bugs Found
None

## Files Modified
- [x] `tests/test_metrics_total_time_computation.sh`
- [x] `tests/test_duration_estimation_jsonl.sh`
- [x] `tests/test_duration_estimation_shell_fallback.sh`
