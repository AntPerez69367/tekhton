# SCOUT_REPORT.md — Milestone 15: Pipeline Lifecycle Consolidation

## Relevant Files

- **tekhton.sh** — Entry point: lines 755, 955, 958, 964, 973, 977, 981 have scattered post-pipeline calls; lines 1082-1099 have interactive commit prompt; lines 1121, 1138 have archive_completed_milestone calls. All these must be consolidated into a single finalize_run() call.
- **lib/hooks.sh** — Post-pipeline utilities: already has generate_commit_message(), archive_reports(), run_final_checks(). Must add finalize_run() to orchestrate all bookkeeping in order.
- **lib/drift_cleanup.sh** — Non-blocking notes management: already has clear_completed_nonblocking_notes() but lacks clear_resolved_nonblocking_notes() to purge ## Resolved section. Must add this new function.
- **lib/milestone_archival.sh** — Milestone archival: archive_completed_milestone() currently leaves [DONE] one-liner summaries in CLAUDE.md. Must be refactored to REMOVE the [DONE] marker entirely after archival and add a comment at the top instead.
- **lib/milestone_ops.sh** — Milestone operations: check_milestone_acceptance() and related functions present. Must add mark_milestone_done() to prepend [DONE] to milestone heading when acceptance passes.
- **lib/config_defaults.sh** — Default values: AUTO_COMMIT defaults to false (line 128). Must be changed to true when MILESTONE_MODE=true, false otherwise.
- **stages/coder.sh** — Coder stage: claim_human_notes() is called unconditionally. Must gate this behind should_claim_notes() check. Also must remove any COMPLETE→IN PROGRESS downgrade logic for unaddressed HUMAN_NOTES.
- **lib/notes.sh** — Notes management: claim_human_notes() marks all notes [~] unconditionally. Must add should_claim_notes(task) gating function and modify claim_human_notes() to use it. Must remove HUMAN_NOTES_ALL_ADDRESSED export (line 64).
- **prompts/coder.prompt.md** — Coder prompt: {{IF:HUMAN_NOTES_BLOCK}} conditional section already present. No changes needed to template itself; behavior change comes from gating claim_human_notes() in notes.sh.
- **lib/drift.sh** — Drift log management: sources are used by drift_cleanup.sh and drift_artifacts.sh. No direct modification needed for this milestone.
- **lib/drift_artifacts.sh** — Drift artifact processing: process_drift_artifacts() is called in tekhton.sh. No internal changes needed; will be called via finalize_run().
- **lib/metrics.sh** — Metrics recording: record_run_metrics() is called multiple times in tekhton.sh and must be called once in finalize_run(). No internal changes needed.
- **lib/milestones.sh** — Milestone state: parse_milestones(), check_milestone_acceptance(), get_milestone_disposition() are used by milestone_ops.sh and tekhton.sh. No changes needed.

## Key Symbols

- `finalize_run()` — **lib/hooks.sh** (new function) — consolidated post-pipeline bookkeeping orchestrator, calls in order: run_final_checks, process_drift_artifacts, record_run_metrics, clear_resolved_nonblocking_notes, archive_reports, mark_milestone_done, auto-commit, archive_completed_milestone
- `run_final_checks()` — **lib/hooks.sh** (existing) — runs analyze/test commands, called from finalize_run
- `process_drift_artifacts()` — **lib/drift_artifacts.sh** (existing) — processes drift observations, called from finalize_run
- `record_run_metrics()` — **lib/metrics.sh** (existing) — records run metrics, called from finalize_run
- `archive_reports()` — **lib/hooks.sh** (existing) — archives agent reports, called from finalize_run
- `archive_completed_milestone()` — **lib/milestone_archival.sh** (existing, to be modified) — moves completed milestone to archive and removes [DONE] line from CLAUDE.md
- `mark_milestone_done()` — **lib/milestone_ops.sh** (new function) — prepends [DONE] to milestone heading in CLAUDE.md
- `clear_resolved_nonblocking_notes()` — **lib/drift_cleanup.sh** (new function) — empties ## Resolved section of NON_BLOCKING_LOG.md
- `should_claim_notes(task)` — **lib/notes.sh** (new function) — returns true only if task references notes or --with-notes flag set
- `claim_human_notes()` — **lib/notes.sh** (existing, to be modified) — now gated by should_claim_notes()
- `AUTO_COMMIT` — **lib/config_defaults.sh** (existing, to be modified) — defaults to true in MILESTONE_MODE, false otherwise

## Suspected Root Cause Areas

1. **Scattered bookkeeping in tekhton.sh** — Post-pipeline calls are at lines 755, 955-958, 964, 973, 977, 981, and 1121/1138 (commit phase). No single ordering guarantee exists. Consolidating into finalize_run() creates a deterministic sequence.
2. **NON_BLOCKING_LOG.md accumulation** — clear_completed_nonblocking_notes() only removes [x] items from ## Open, but ## Resolved section accumulates forever. New clear_resolved_nonblocking_notes() needed post-run.
3. **CLAUDE.md [DONE] noise** — archive_completed_milestone() creates one-liner [DONE] summaries that persist and accumulate. Must be removed entirely; completed milestones live only in MILESTONE_ARCHIVE.md.
4. **Milestone [DONE] chicken-and-egg** — Nothing programmatically marks milestone as [DONE] before archival searches for it. New mark_milestone_done() must run after acceptance passes, before archival.
5. **HUMAN_NOTES phantom injection** — claim_human_notes() runs unconditionally in coder stage, marking all notes [~] even when task has nothing to do with them. Notes get ignored, reset on next run, cycle repeats. Gating via should_claim_notes() fixes this.
6. **Interactive commit blocking in autonomous mode** — _prompt_commit() reads stdin, blocking milestone mode and --complete runs. AUTO_COMMIT default to true in milestone mode fixes this.
7. **AUTO_COMMIT not default in milestone mode** — Currently defaults to false everywhere; milestone mode needs auto-commit enabled by default to support autonomous progression.

## Complexity Estimate

Files to modify: 9
Estimated lines of change: 370
Interconnected systems: high
Recommended coder turns: 75
Recommended reviewer turns: 13
Recommended tester turns: 50
