## Planned Tests
- [x] `tests/test_dry_run.sh` — cache roundtrip, TTL expiry, git HEAD mismatch, consume flags, parse helpers, syntax/shellcheck

## Test Run Results
Passed: 33  Failed: 0

## Bugs Found
- BUG: [lib/dry_run.sh:289] `_parse_intake_preview` uses `grep -A2 '## Verdict' | tail -1` which lands on the blank line after the verdict value when the actual intake report format is `## Verdict\nPASS\n` — returns "N/A" instead of the correct verdict

## Files Modified
- [x] `tests/test_dry_run.sh`
