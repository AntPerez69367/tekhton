# Reviewer Report — M53: Error Pattern Registry & Build Gate Classification

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `lib/error_patterns.sh` is 337 lines, exceeds the 300-line soft ceiling. The registry heredoc accounts for the bulk; consider splitting the registry data from the classification engine if it grows further.
- `lib/errors.sh` is 304 lines, marginally over the ceiling — acceptable but worth noting for future cleanup.

## Coverage Gaps
- `annotate_build_errors` is only tested with a code-category error. The non-code branch (env_setup with `Auto-fix:` remediation line) is exercised by the gate tests but not unit-tested in `test_error_patterns.sh` directly.
- `filter_code_errors` is not tested for all-code input (no non-code errors present) or all-noncode input (no code errors present) — only mixed input is tested.

## Drift Observations
- `lib/gates.sh` Phase 4 (UI test path) does not write `BUILD_RAW_ERRORS.txt`. When UI tests fail with non-code errors, `coder.sh` falls back to `BUILD_ERRORS.md` (annotated markdown), which causes `has_only_noncode_errors` to return 1 (markdown headers produce unclassified→code fallback), preventing bypass. Phase 4 has auto-remediation for `env_setup` issues but not the full bypass routing that Phases 1–2 provide. This is intentionally documented as a known limitation in `test_gates_bypass_flow.sh` (Test 2). Candidate for M54 improvement.
- `classify_build_error` (single-line semantics, first-match on full multi-line input) and `classify_build_errors_all` (per-line with dedup) serve different purposes but are easily confused. Phase 4 auto-remediation uses `classify_build_error` on the full UI test output — this works in practice because env_setup patterns (e.g., "npx playwright install") appear early in playwright output, but the inconsistency could mislead future maintainers.
