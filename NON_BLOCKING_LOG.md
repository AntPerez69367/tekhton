# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-05 | "[BUG] The Milestone Map is no longer showing the currently active milestone in the Active column. It remains in the READY column and then jumps to DONE when completed, without ever showing as ACTIVE."] `templates/watchtower/app.js`: `msIdMatch()` is defined as an inner function mid-body inside `renderMilestonesByStatus()` rather than near the top of that function. Minor readability concern — inner functions are easier to spot when hoisted to the top of the enclosing function.
- [ ] [2026-04-05 | "[BUG] The Milestone Map is no longer showing the currently active milestone in the Active column. It remains in the READY column and then jumps to DONE when completed, without ever showing as ACTIVE."] `orchestrate.sh` / `orchestrate_helpers.sh`: The `command -v emit_dashboard_milestones &>/dev/null` guard is always true when these files run under `tekhton.sh` (since `dashboard_emitters.sh` is unconditionally sourced). The guard is harmless and defensive, but a comment noting why it exists would help future readers understand the intent vs. a dead check.
(none)



## Resolved
