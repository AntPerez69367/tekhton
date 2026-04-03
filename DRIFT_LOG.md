# Drift Log

## Metadata
- Last audit: 2026-04-03
- Runs since audit: 5

## Unresolved Observations
- [2026-04-03 | "M54"] `_gate_write_compile_errors` (gates_phases.sh:127–141) guards its classification block with `command -v annotate_build_errors`, but the body calls `classify_build_errors_all`. Both functions live in error_patterns.sh so the guard works, but the checked name and the called name differ — a reader would expect the guard to match the called function.
- [2026-04-03 | "Address all 5 open non-blocking notes in NON_BLOCKING_LOG.md. Fix each item and note what you changed."] `lib/gates.sh:170` — The Phase 2 header guard checks `[[ ! -f BUILD_ERRORS.md ]]` at write time inside the redirect block. A stale BUILD_ERRORS.md from a prior failed run (not cleaned at gate entry) would suppress the header and cause new compile errors to be appended to old content. This is a pre-existing issue (not introduced by this PR) but worth noting for a future audit pass.
- [2026-04-03 | "architect audit"] **`lib/error_patterns.sh:119-123` — `cut` fork count in `load_error_patterns()`** The reviewer explicitly classified this as a performance note and stated "correctness is fine" and the current count (260 forks) is "acceptable for 52 patterns." `load_error_patterns()` executes once per pipeline run with a result cached in `_EP_LOADED`. The performance cost is bounded and not observable at runtime. Replacing five `cut` invocations with bash parameter expansion on a 52-entry table would be premature optimization. If the registry grows past ~500 patterns, this should be revisited. No action now.

## Resolved
