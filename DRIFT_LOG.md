# Drift Log

## Metadata
- Last audit: 2026-04-03
- Runs since audit: 1

## Unresolved Observations
- [2026-04-03 | "architect audit"] **`lib/error_patterns.sh:119-123` — `cut` fork count performance note** The drift observation itself concludes "No action now" and explicitly states correctness is not in question. The classification body in `load_error_patterns()` executes once per pipeline run with results cached in `_EP_LOADED`; at 52 patterns the cost is not observable. Replacing five `cut` invocations with bash parameter expansion would be premature optimization. The observation recommends revisiting only if the registry grows past ~500 patterns. This item requires no code change at this time. It should remain in the drift log for future consideration if the registry grows significantly.

## Resolved
- [RESOLVED 2026-04-03] `_gate_write_compile_errors` (gates_phases.sh:127–141) guards its classification block with `command -v annotate_build_errors`, but the body calls `classify_build_errors_all`. Both functions live in error_patterns.sh so the guard works, but the checked name and the called name differ — a reader would expect the guard to match the called function.
- [RESOLVED 2026-04-03] `lib/gates.sh:170` — The Phase 2 header guard checks `[[ ! -f BUILD_ERRORS.md ]]` at write time inside the redirect block. A stale BUILD_ERRORS.md from a prior failed run (not cleaned at gate entry) would suppress the header and cause new compile errors to be appended to old content. This is a pre-existing issue (not introduced by this PR) but worth noting for a future audit pass.
- [RESOLVED 2026-04-03] **`lib/error_patterns.sh:119-123` — `cut` fork count in `load_error_patterns()`** The reviewer explicitly classified this as a performance note and stated "correctness is fine" and the current count (260 forks) is "acceptable for 52 patterns." `load_error_patterns()` executes once per pipeline run with a result cached in `_EP_LOADED`. The performance cost is bounded and not observable at runtime. Replacing five `cut` invocations with bash parameter expansion on a 52-entry table would be premature optimization. If the registry grows past ~500 patterns, this should be revisited. No action now.
