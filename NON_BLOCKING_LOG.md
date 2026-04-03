# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-03 | "M54"] `_route_to_human_action()` (error_patterns_remediation.sh:181–196) builds a multi-line `desc` variable but never passes it anywhere — only `oneline` reaches `append_human_action`. The `desc` block is dead code. Shellcheck may flag this as SC2034. Remove or use `desc` instead of `oneline` if richer output is intended.
- [ ] [2026-04-03 | "M54"] `error_patterns_remediation.sh` lands at 288 lines — 12 lines under the 300-line ceiling. Future additions should target a split before that limit is reached.
- [ ] [2026-04-03 | "M54"] ARCHITECTURE.md update (add `error_patterns_remediation.sh` and `gates_phases.sh` to the Library layer table) is called out in both ACPs as needed. This was not done as part of M54 — schedule for the next cleanup pass.
(none)

## Resolved
