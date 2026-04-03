# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-03 | "M53"] `lib/gates.sh` file size: Still 413 lines (over 300-line ceiling by 113 lines). Partial progress via extraction of completion gate to `lib/gates_completion.sh`, but `run_build_gate()` remains as cohesive unit. Ceiling exception requires explicit acceptance or gates.sh must reach ≤300 lines. Test suite does not enforce this ceiling.

## Resolved
