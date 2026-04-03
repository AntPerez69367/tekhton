# JR Coder Summary — Architect Remediation

## What Was Fixed

- **SF-1**: Added doc comment to `annotate_build_errors()` in `lib/error_patterns.sh` (line 266–267) clarifying that raw error text is NOT included in the function output and callers must write raw errors separately to `BUILD_RAW_ERRORS.txt`. This makes the implicit API contract explicit and prevents future misuse.

- **SF-2**: Removed ten verification summary lines from `DRIFT_LOG.md` (`## Unresolved Observations` section). These lines (`-- **Verification summary (from coder):**` through `Registry-based UI auto-remediation...`) were build-gate output accidentally appended to the drift log. They are not architectural observations and were polluting the drift log's unresolved observation count.

## Files Modified

- `lib/error_patterns.sh` — Added two-line doc comment (no code changes)
- `DRIFT_LOG.md` — Removed nine extraneous verification summary lines

## Verification

- `bash -n lib/error_patterns.sh` — **PASS**
- `shellcheck lib/error_patterns.sh` — **CLEAN** (0 warnings)
