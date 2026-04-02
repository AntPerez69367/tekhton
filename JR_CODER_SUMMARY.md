# Junior Coder Summary

## What Was Fixed

- **Staleness Fix 1:** Added explanatory comment to `_parse_run_summaries_from_files` (line 388) clarifying why no zero-turn filter is required for the legacy RUN_SUMMARY_*.json fallback path. Comment notes that these files are only written on successful completion, never by error traps or crash paths.

- **Staleness Fix 2:** Added explanatory comment to `_parse_run_summaries_from_jsonl` bash fallback (lines 372-377) documenting the divergent depth-counting semantics between the Python and bash implementations. Python takes the last `depth` lines then filters zeros (zeros consume budget), while bash filters zeros per-record with `continue` (zeros don't consume budget). The comment explains this is benign for normal usage but results in record count divergence when many crash records are present and depth is binding.

## Files Modified

- `lib/dashboard_parsers.sh`

## Verification

- `bash -n lib/dashboard_parsers.sh` ✓ Passed
- `shellcheck lib/dashboard_parsers.sh` ✓ Passed
