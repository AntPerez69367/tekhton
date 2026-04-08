# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-08 | "[BUG] Greenfield plan Milestone Summary incorrectly reports "0 milestones" and "No milestone headings found in CLAUDE.md" even when milestones were successfully generated in `.claude/milestones/`. The summary display logic is looking for milestone headings in CLAUDE.md (the old inline location) instead of counting files in the DAG milestone directory. Fix the milestone count and warning message in the plan review/summary display to check the milestone directory when `MILESTONE_DAG_ENABLED` is true."] `plan_milestone_review.sh:40` — the iteration loop accesses the internal `_DAG_IDS[]` array directly instead of going through a public API. No `dag_get_id_at_index()` exists so this is the pragmatic choice, but it creates a coupling to the private array name.
(none)

## Resolved
