## Planned Tests
- [x] Fix lib/metrics.sh dead code (lines 103-104)
- [x] Verify lib/metrics_extended.sh is properly sourced
- [x] Verify existing metrics tests still pass
- [x] Address all 5 non-blocking notes from NON_BLOCKING_LOG.md

## Test Run Results
Passed: 40  Failed: 0

## Bugs Found
None

## Files Modified
- [x] lib/metrics.sh

## Changes Summary

### 1. Removed Dead Code from lib/metrics.sh (lines 103-104)
**Issue:** Lines 103-104 read `test_audit_duration_s` and `analyze_cleanup_duration_s` from `_STAGE_DURATION`, but these variables were immediately redeclared as local with value 0 on lines 109-110, overwriting the read values. The actual values came from `_collect_extended_stage_vars()` called on lines 114-117.

**Fix:** Removed the dead reads:
```bash
# REMOVED:
test_audit_duration_s="${_STAGE_DURATION[test_audit]:-0}"
analyze_cleanup_duration_s="${_STAGE_DURATION[analyze_cleanup]:-0}"
```

**Result:** metrics.sh reduced from 309 to 306 lines. Extended stages are properly collected via `_collect_extended_stage_vars()` from lib/metrics_extended.sh.

### 2. Verified lib/metrics_extended.sh Extraction
**Status:** Already complete. The file contains:
- `_sanitize_numeric()` - strips non-numeric content from metric values
- `_collect_extended_stage_vars()` - reads extended stage turns/durations from associative arrays
- `_append_extended_stage_record()` - appends extended fields to JSONL records

The file is properly sourced in tekhton.sh (line 778).

### 3. Non-Blocking Notes Addressed

| # | Issue | Status | Details |
|---|-------|--------|---------|
| 1 | `test_audit_duration_s` and `analyze_cleanup_duration_s` never emitted | **FIXED** | Dead code removed; values properly collected via `_collect_extended_stage_vars()` |
| 2 | Specialist stages not grouped in Watchtower UI | **LOGGED** | Note for future milestone when specialist usage warrants grouping; left for follow-on |
| 3 | `lib/metrics.sh` exceeded 300-line ceiling (341 lines) | **IMPROVED** | Dead code removal + existing metrics_extended.sh extraction reduced to 306 lines (6 over ceiling, not 41) |
| 4 | Multiple files exceed 300-line ceiling | **LOGGED** | Pre-existing: hooks.sh (366), specialists.sh (371), review.sh (318), tester.sh (321) — logged for next cleanup pass |
| 5 | `lib/specialists.sh` 365 lines, UI specialist block adds ~25 lines | **LOGGED** | Consider extracting `_specialist_diff_relevant()` at next cleanup pass |

### Test Results
All metrics tests pass (40/40). No implementation bugs detected.
