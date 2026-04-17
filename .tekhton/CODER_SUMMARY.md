# Coder Summary

## Status: COMPLETE

## What Was Implemented

Milestone 93 — Rejection Artifact Preservation & Smart Resume Routing.

When the orchestrator hits a save-and-exit (`max_attempts`, `timeout`,
`agent_cap`, `stuck`, `usage_threshold`, `pre_existing_failure`,
`review_exhausted`, `build_exhausted`, `split_exhausted`, etc.), the resume
command in `PIPELINE_STATE.md` previously hardcoded `--start-at ${START_AT}`,
which forced users back to the coder stage even when a usable
`REVIEWER_REPORT.md` already existed (or had been archived at startup of the
failing run). This milestone makes the resume command smart:

1. **`tekhton.sh`** — In the startup archive loop (which fires when
   `START_AT` is `coder` or `intake`), the destination path of any archived
   `REVIEWER_REPORT.md` and `TESTER_REPORT.md` is recorded in two new
   exported globals: `_ARCHIVED_REVIEWER_REPORT_PATH` and
   `_ARCHIVED_TESTER_REPORT_PATH`.

2. **`lib/orchestrate_helpers.sh`** — New function
   `_choose_resume_start_at()` decides the smartest `--start-at` based on
   what's currently on disk or what was archived at startup. Resolution
   order: in-run REVIEWER_REPORT → archived REVIEWER_REPORT (cp-restored) →
   in-run TESTER_REPORT → archived TESTER_REPORT (cp-restored) →
   `${START_AT}` fallback. Restoration uses `cp` (not `mv`) so the archive
   log entry stays intact.

3. **`_save_orchestration_state()`** now calls `_choose_resume_start_at`
   before composing `resume_flags`, so the persisted resume command and
   user-facing warning both reflect the smartest available `--start-at`.
   When restoration occurred, the `Notes` field of `PIPELINE_STATE.md`
   appends `| Restored REVIEWER_REPORT.md from <archive_path>` so the user
   can see why a particular resume command is recommended.

## Root Cause (bugs only)

Two compounding bugs:

1. **Archive-on-start destroyed the resume path.** The startup loop in
   `tekhton.sh` (line 1947) archived `REVIEWER_REPORT.md` whenever
   `--start-at coder` was used. After that, `--start-at test` was
   impossible — the file was gone — even if the reviewer had successfully
   approved in a prior attempt.
2. **`_save_orchestration_state` always wrote `--start-at ${START_AT}`.**
   When the reviewer ran and approved but the coder rework loop exhausted
   its budget, the right resume point was `--start-at test`. The state
   writer didn't know that and forced the user back to coder.

## Files Modified

- `tekhton.sh` — added `_ARCHIVED_REVIEWER_REPORT_PATH` /
  `_ARCHIVED_TESTER_REPORT_PATH` declarations + `case` arm in the archive
  loop to populate them.
- `lib/orchestrate_helpers.sh` — added `_choose_resume_start_at()` and
  rewired `_save_orchestration_state()` to use it. Also appends the
  restoration note to the state file's `Notes` field.
- `tests/test_rejection_artifact_preservation.sh` (NEW) — 8 scenarios, 20
  assertions covering: in-run reviewer/tester present, archived-then-restored
  paths for both, fallback to `START_AT` when nothing exists, reviewer
  priority over tester, stale-archive-path graceful fallthrough, and the
  restoration log line.

## Human Notes Status

No human notes for this milestone task.

## Docs Updated

None — no public-surface changes in this task. The milestone adds no CLI
flags, no config keys, no exported functions; the new globals
(`_ARCHIVED_*_PATH`, `_RESUME_NEW_START_AT`, `_RESUME_RESTORED_ARTIFACT`)
are private-by-convention (leading underscore) and used only by
`_save_orchestration_state`. No `Documentation Responsibilities` section
in CLAUDE.md applies.
