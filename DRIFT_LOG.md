# Drift Log

## Metadata
- Last audit: 2026-04-03
- Runs since audit: 3

## Unresolved Observations
- [2026-04-03 | "Address all 5 open non-blocking notes in NON_BLOCKING_LOG.md. Fix each item and note what you changed."] `lib/gates.sh:170` — The Phase 2 header guard checks `[[ ! -f BUILD_ERRORS.md ]]` at write time inside the redirect block. A stale BUILD_ERRORS.md from a prior failed run (not cleaned at gate entry) would suppress the header and cause new compile errors to be appended to old content. This is a pre-existing issue (not introduced by this PR) but worth noting for a future audit pass.
- [2026-04-03 | "architect audit"] **`lib/error_patterns.sh:119-123` — `cut` fork count in `load_error_patterns()`** The reviewer explicitly classified this as a performance note and stated "correctness is fine" and the current count (260 forks) is "acceptable for 52 patterns." `load_error_patterns()` executes once per pipeline run with a result cached in `_EP_LOADED`. The performance cost is bounded and not observable at runtime. Replacing five `cut` invocations with bash parameter expansion on a 52-entry table would be premature optimization. If the registry grows past ~500 patterns, this should be revisited. No action now.

## Resolved
- [RESOLVED 2026-04-03] `lib/error_patterns.sh:119-123` — `load_error_patterns()` uses `echo "$line" | cut -d'|' -f1..5` (five `cut` forks per pattern, 260 forks total on load). Since loading is cached this is acceptable for 52 patterns, but if the registry grows significantly (M54/M55 project-level extensions) this pattern costs more than bash parameter expansion would. Purely a performance note — correctness is fine.
- [RESOLVED 2026-04-03] `lib/error_patterns.sh:266-267` — `annotate_build_errors()` does not include raw error output in its return value; callers in `gates.sh` must write raw errors separately. The API contract is implicit and only visible by reading both files. A doc comment on `annotate_build_errors` clarifying "caller is responsible for appending raw output" would prevent future misuse.
