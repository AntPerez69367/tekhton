## Planned Tests
- [x] `tests/test_init_recommendation.sh` — add truncation test: >8 entries in _init_render_files_written shows "plus N more"

## Test Run Results
Passed: 355  Failed: 0

## Bugs Found
None

## Files Modified
- [x] `tests/test_init_recommendation.sh`

## Known Gaps
- `INIT_AUTO_PROMPT=true` code path (`_emit_auto_prompt`): requires an interactive TTY (`[[ -t 0 ]]` and `[[ -t 1 ]]`). Untestable in a non-interactive CI harness. Documented as known gap.
