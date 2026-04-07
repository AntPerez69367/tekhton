# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-07 | "M64"] `stages/tester_fix.sh` is sourced twice: once at the end of `tester.sh` (line 398) and once explicitly in `tekhton.sh` (line 815). Double-sourcing is harmless (functions are redefined to the same definition) but the `tekhton.sh` entry is redundant and could be removed.
(none)

## Resolved
