# Drift Log

## Metadata
- Last audit: 2026-03-30
- Runs since audit: 2

## Unresolved Observations
- [2026-03-30 | "[BUG] Watchtower Trends page: Average stage times are incorrect. Tester shows 3:38 avg despite no run under 5 min; an 11-min run decreased the average to 3:21 instead of increasing it. The average run time shows as 8m50s when in actual fact most runs are well over 20 minutes, some reaching over an hour. This is critical for users to have an accurate expectation of how long runs will take and to see the impact of their optimizations."] `lib/dashboard_parsers.sh:236–239` (shell fallback) and the equivalent Python block: duration estimation assumes turns-per-stage is a proxy for time-per-stage. If the codebase ever records stage durations directly for all stages (making the estimate unnecessary), the two estimation blocks become dead code — worth a cleanup note when `_STAGE_DURATION` coverage is confirmed complete.
- [2026-03-30 | "[BUG] Watchtower Trends page: Average stage times are incorrect. Tester shows 3:38 avg despite no run under 5 min; an 11-min run decreased the average to 3:21 instead of increasing it. The average run time shows as 8m50s when in actual fact most runs are well over 20 minutes, some reaching over an hour. This is critical for users to have an accurate expectation of how long runs will take and to see the impact of their optimizations."] `lib/metrics.sh:107` iterates over a hardcoded list (`intake scout coder build_gate security reviewer tester`) to sum `_STAGE_DURATION`. If new stages are added in future milestones, this list will silently miss them and undercount `total_time`. Consider using a loop over all keys of `_STAGE_DURATION` instead (`"${!_STAGE_DURATION[@]}"`) to be future-proof.
(none)

## Resolved
- [RESOLVED 2026-03-30] Watchtower Trends page: Recent Runs section does not show the latest two --human runs, it only shows the last --milestone run.**"] `templates/watchtower/app.js:484,575` — Two remaining `(s.run_type || 'milestone')` fallbacks exist for the live-run / active pipeline state display (different from the historical runs list fixed here). If a live run has no `run_type`, it displays as "milestone" in the live status card. Worth a follow-up pass to confirm whether `'adhoc'` (or an explicit sentinel) is the correct default there too.
- [RESOLVED 2026-03-30] Watchtower Reports page: Test Audit section never displays any information"] `templates/watchtower/app.js` — The emitter→renderer contract (data shape) is implicit; a comment on `renderTestAuditBody()` documenting the expected fields (`verdict`, `high_findings`, `medium_findings`) would prevent re-introducing the same mismatch
