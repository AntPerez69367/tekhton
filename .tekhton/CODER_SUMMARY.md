# Coder Summary

## Status: COMPLETE

## What Was Implemented
Added `tui_reset_for_next_milestone()` in `lib/tui_ops.sh` and wired it into
`_run_auto_advance_chain` in `lib/orchestrate_helpers.sh` so milestone 2+ of an
auto-advance chain re-enter `run_complete_loop` with grey pills instead of
inheriting the prior milestone's green completion row.

The reset clears:
- `_TUI_STAGES_COMPLETE` (the pill-completion records — primary culprit)
- `_TUI_RECENT_EVENTS` (event ring buffer, scoped per milestone)
- Current-stage progress fields (`_TUI_CURRENT_STAGE_LABEL`, `_NUM`, `_TOTAL`,
  `_MODEL`, `_TUI_AGENT_STATUS`, `_TUI_AGENT_TURNS_USED/MAX`, `_ELAPSED_SECS`,
  `_TUI_STAGE_START_TS`, `_TUI_CURRENT_LIFECYCLE_ID`)
- Substage fields (`_TUI_CURRENT_SUBSTAGE_LABEL`, `_TUI_CURRENT_SUBSTAGE_START_TS`)

The reset deliberately preserves:
- `_TUI_ACTIVE` (the sidecar lifespan matches the outer tekhton.sh invocation
  per M111's multipass contract)
- `_TUI_STAGE_ORDER` (the pill list for this run's stage plan)
- `_TUI_PIPELINE_START_TS` (overall session uptime)
- `_TUI_STAGE_CYCLE` + `_TUI_CLOSED_LIFECYCLE_IDS` (monotonic across the whole
  sidecar session so stale late spinner ticks from prior milestones continue
  to be rejected)

## Root Cause (bugs only)
`_run_auto_advance_chain` in `lib/orchestrate_helpers.sh` recursively re-entered
`run_complete_loop` on milestone transition after resetting orchestration
counters (`_ORCH_*`) but without resetting TUI display state. The globals
`_TUI_STAGES_COMPLETE` and `_TUI_RECENT_EVENTS` in `lib/tui.sh` are module-level
arrays that persist across pipeline iterations by design (to support M111's
multipass sidecar-stays-active contract within a single milestone), but that
persistence is wrong across milestone boundaries — the user expects milestone 2
to start with a fresh pipeline view. No reset helper existed; one was needed.

## Files Modified
- `lib/tui_ops.sh` — added `tui_reset_for_next_milestone()` public helper
- `lib/orchestrate_helpers.sh` — call the helper inside `_run_auto_advance_chain`
  right before re-entering `run_complete_loop`
- `tests/test_tui_multipass_lifecycle.sh` — extended with Tests 7–10 covering
  per-milestone state isolation, lifecycle-counter preservation, inactive
  no-op, and an end-to-end auto-advance simulation
- `ARCHITECTURE.md` — added `tui_reset_for_next_milestone()` to the lib/tui_ops.sh
  API list

## Docs Updated
`ARCHITECTURE.md` — added the new public helper to the tui_ops.sh module entry
in the library map.

## Human Notes Status
- NOT_ADDRESSED: [BUG] GitHub Pages/release workflow checkout fails with `fatal: no url found for submodule path '.claude/worktrees/agent-a049075c' in .gitmodules` because the repo tree contains a committed gitlink at `.claude/worktrees/agent-a049075c` (mode 160000) but no `.gitmodules` entry. Root cause is accidental tracking of a local git worktree under `.claude/worktrees/` (not currently ignored). Triage/fix: remove the gitlink from index/history tip (`git rm --cached .claude/worktrees/agent-a049075c`), add `.claude/worktrees/` to `.gitignore`, and add a CI guard that fails if `git ls-files --stage` contains mode 160000 paths outside approved submodules. (Out of scope — this note concerns a committed gitlink / CI guard that is unrelated to the TUI state-leak bug this task targets. Leaving for a dedicated infra task so scope stays tight.)
