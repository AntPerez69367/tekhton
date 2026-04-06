# Drift Log

## Metadata
- Last audit: 2026-04-05
- Runs since audit: 2

## Unresolved Observations
- [2026-04-05 | "Address all 5 open non-blocking notes in NON_BLOCKING_LOG.md. Fix each item and note what you changed."] `lib/metrics.sh` now has two separate read blocks for `_STAGE_DURATION` within `record_run_metrics()` — the primary block (lines 93-105) reads coder/reviewer/tester/scout/security/cleanup durations, and the extended block (lines 107-117) reads test_audit/analyze_cleanup/specialist durations via `_collect_extended_stage_vars()`. The split is intentional but the overlap (lines 103-104 vs lines 109-110) creates confusion. A future cleanup could merge both blocks into a single `_collect_extended_stage_vars()` call or document the boundary explicitly.
- [2026-04-05 | "Address all 5 open non-blocking notes in NON_BLOCKING_LOG.md. Fix each item and note what you changed."] The five addressed notes remain `[ ]` in `NON_BLOCKING_LOG.md` — the pipeline marks them resolved post-run via the hooks mechanism, so this is expected mid-pipeline state, not an omission.
- [2026-04-05 | "Milestone 66"] `lib/dashboard_parsers_runs.sh:250-254`: The bash fallback injects `"cycles":N` and `"rework_cycles":N` into the JSON string using `sed` pattern replacement after the `stages_json` loop. If any future field is added before `"reviewer":{` or `"security":{` that also starts with `"reviewer":` or `"security":`, the injection point could shift. Consider a builder approach instead of post-hoc string surgery.
- [2026-04-05 | "Milestone 66"] `stages/tester.sh:355-393`: The test_audit sub-step tracking block appears twice — once in the continuation path (line 355-361) and once in the clean-completion path (line 387-393). The code is identical. Consider extracting to a shared helper `_record_test_audit_substep` to avoid future divergence.

## Resolved
