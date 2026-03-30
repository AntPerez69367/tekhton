# Reviewer Report

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- Historical JSONL records that already have an under-reported `total_time_s` (recorded before this fix) will continue to pull down averages until enough new correct records accumulate. This is an unavoidable side-effect of fixing a metric recording bug and requires no code change, but users should be aware averages will improve gradually over subsequent runs.
- The proportional per-stage duration estimation (`time_s * turns / total_turns`) is an approximation that breaks down when a stage uses many turns but runs quickly (or few turns but runs slowly — e.g., long model think times). For averages across many runs it's acceptable, but a Drift Observation is noted below.

## Coverage Gaps
- No test covers the new `total_time` computation path in `record_run_metrics()` — specifically that `_STAGE_DURATION` sum takes precedence over `TOTAL_TIME` and that the fallback to `TOTAL_TIME` fires when the array is empty.
- No test for the new proportional duration estimation branch in `_parse_run_summaries_from_jsonl` (both Python and shell paths).

## Drift Observations
- `lib/dashboard_parsers.sh:236–239` (shell fallback) and the equivalent Python block: duration estimation assumes turns-per-stage is a proxy for time-per-stage. If the codebase ever records stage durations directly for all stages (making the estimate unnecessary), the two estimation blocks become dead code — worth a cleanup note when `_STAGE_DURATION` coverage is confirmed complete.
- `lib/metrics.sh:107` iterates over a hardcoded list (`intake scout coder build_gate security reviewer tester`) to sum `_STAGE_DURATION`. If new stages are added in future milestones, this list will silently miss them and undercount `total_time`. Consider using a loop over all keys of `_STAGE_DURATION` instead (`"${!_STAGE_DURATION[@]}"`) to be future-proof.
