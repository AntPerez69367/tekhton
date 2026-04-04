# Drift Log

## Metadata
- Last audit: 2026-04-04
- Runs since audit: 1

## Unresolved Observations
(none)

## Resolved
- [RESOLVED 2026-04-04] `_pf_infer_from_compose` service-transition fragility — Added `continue` after service name match in `preflight_services_infer.sh:44-49` so that a new service line is never re-evaluated by port/image checks below. Eliminates the subtle ordering dependency.
- [RESOLVED 2026-04-04] `trap - INT TERM` global signal clearing in `_call_planning_batch` — Replaced bare `trap - INT TERM` with save/restore of previous trap handlers in `plan.sh:200-228`. Previous handlers are captured via `trap -p` before the temporary trap is set, then restored with `eval` after cleanup.
- [RESOLVED 2026-04-04] `preflight.sh` at 618 lines (2× the 300-line ceiling) — Split into three files: `preflight.sh` (199 lines: state, helpers, report, orchestrator), `preflight_checks.sh` (224 lines: checks 1-4), `preflight_checks_env.sh` (226 lines: checks 5-7). All under the 300-line ceiling. `tekhton.sh` updated to source the new files.
- [RESOLVED 2026-04-04] **`lib/error_patterns.sh:119-123` — `cut` fork count performance note** The drift observation itself concludes "No action now" and explicitly states correctness is not in question. The classification body in `load_error_patterns()` executes once per pipeline run with results cached in `_EP_LOADED`; at 52 patterns the cost is not observable. Replacing five `cut` invocations with bash parameter expansion would be premature optimization. The observation recommends revisiting only if the registry grows past ~500 patterns. This item requires no code change at this time. It should remain in the drift log for future consideration if the registry grows significantly.
