# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-03-18 | "Implement Milestone 11: Pre-Flight Milestone Sizing And Null-Run Auto-Split"] `lib/milestone_archival.sh` is still not listed under "Files Modified" in CODER_SUMMARY.md despite being modified in this cycle (git status confirms it changed). This is the third cycle in a row with this omission. Not a correctness issue, but makes change tracking difficult.
- [ ] [2026-03-18 | "Implement Milestone 11: Pre-Flight Milestone Sizing And Null-Run Auto-Split"] Em-dash (`â€”`, U+2014) in regex character classes (`[:.€”-]`) remains unaddressed in `milestone_archival.sh` at lines 34, 79, 99, 161, and 223 â€” portability concern noted in Cycle 1. Still non-blocking, but now a persistent observation across three cycles.
(none)

## Resolved
- [x] [2026-03-17] Coder scope drift â€” audited all items instead of task-specified quantity. Resolved by adding scope-adherence directive to `prompts/coder.prompt.md` and softening the "address what you can" language in `stages/coder.sh` non-blocking injection to defer to task scope.
- [x] [2026-03-17] (consolidated) `milestones.sh` exceeded the 300-line guideline. Resolved by extracting acceptance checking, commit signatures, and auto-advance helpers into `lib/milestone_ops.sh`. `milestones.sh` is now ~312 lines, `milestone_ops.sh` ~260 lines.
- [x] [2026-03-17] Three duplicate "milestones.sh too long" entries consolidated into a single resolved entry above.
