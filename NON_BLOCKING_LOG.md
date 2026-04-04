# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-04 | "Resolve all 4 unresolved architectural drift observations in DRIFT_LOG.md."] `preflight_checks_env.sh:133` — `_preflight_check_ports` iterates over `cmd_var` without a `local cmd_var` declaration, leaking the variable to calling scope. Contrast with `_preflight_check_tools` in `preflight_checks.sh:125` which correctly declares `local cmd_var cmd_val cmd_token`. Low risk (variable unused outside the function), but inconsistent with project style and may draw a shellcheck annotation in a future pass.
- [ ] [2026-04-04 | "Resolve all 4 unresolved architectural drift observations in DRIFT_LOG.md."] `plan.sh` is 650 lines — pre-existing condition not introduced by this task, but the file has grown well beyond the 300-line ceiling and warrants an extraction pass in a future milestone.
(none)

## Resolved
