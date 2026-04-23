# Coder Summary

## Status: COMPLETE

## What Was Implemented

Moved acceptance-criteria quality lint from end-of-run acceptance checking
(`check_milestone_acceptance()` in `lib/milestone_acceptance.sh`) to
authoring-time validation (`draft_milestones_validate_output()` in
`lib/draft_milestones_write.sh`). Warnings now surface while the author is
still iterating on the milestone file, where they are actionable.

- Removed the ~40-line lint block from `check_milestone_acceptance()`. The
  acceptance gate is now focused solely on pass/fail checks (tests, build
  gate, manual syntax checks, docs strict mode). A short comment replaces
  the block so future readers understand where lint moved.
- Added a lint invocation to `draft_milestones_validate_output()` after
  structural checks pass. Warnings are emitted to stderr with a `LINT:`
  prefix and the basename of the milestone file. Lint is non-blocking —
  the function still returns 0 so the manifest write proceeds. The call
  is guarded by `declare -f lint_acceptance_criteria &>/dev/null` so the
  function is safe to call in contexts where the helper was not sourced
  (e.g. stripped-down unit tests).
- `lib/milestone_acceptance_lint.sh` is unchanged — same API, new call
  site. `tekhton.sh` already sources the lint helper (line 875) before
  `draft_milestones.sh` (line 879), so the function is available when
  `draft_milestones_write.sh` runs in production.

### Tests

- **`tests/test_milestone_acceptance_lint.sh`** — the integration block
  that previously asserted lint warnings appeared in
  `check_milestone_acceptance` output was inverted: it now asserts lint
  is NOT emitted by the acceptance gate and does NOT write to
  `NON_BLOCKING_LOG`. The pure unit tests for the lint helpers are
  unchanged.
- **`tests/test_draft_milestones_validate_lint.sh` (NEW)** — four
  scenarios:
  1. Structural-only refactor milestone passes validation (lint is
     non-blocking) and emits `LINT:` warnings including the behavioral
     and refactor-completeness checks.
  2. A milestone with behavioral criteria produces no lint warnings.
  3. Validation gracefully skips lint when `lint_acceptance_criteria`
     is not loaded (defensive `declare -f` guard).
- Kept `tests/test_draft_milestones_validate.sh` focused on structural
  validation (tests 1–7) to keep each test file under the 300-line
  ceiling.

### Docs

Updated `ARCHITECTURE.md` entry for `lib/milestone_acceptance_lint.sh` to
note the new call site (authoring-time via
`draft_milestones_validate_output()`).

## Root Cause (bugs only)

The lint check was wired into `check_milestone_acceptance()` — the
end-of-run gate that decides whether a milestone passes. By the time
lint ran there, the milestone file had already been authored, reviewed,
coded, and tested. Warnings about "add behavioral criteria" or "add a
completeness grep" were non-actionable at that point and only cluttered
`NON_BLOCKING_LOG`. The fix is a pure relocation: same rule set, earlier
call site.

## Files Modified

- `lib/milestone_acceptance.sh` — removed lint block from
  `check_milestone_acceptance()` (replaced with a pointer comment)
- `lib/draft_milestones_write.sh` — added non-blocking lint call at the
  end of `draft_milestones_validate_output()`
- `tests/test_milestone_acceptance_lint.sh` — inverted the integration
  assertions (lint must NOT fire at acceptance time)
- `tests/test_draft_milestones_validate_lint.sh` (NEW) — authoring-time
  lint integration coverage
- `ARCHITECTURE.md` — one-line update to reflect new call site

## Docs Updated

- `ARCHITECTURE.md` — `lib/milestone_acceptance_lint.sh` entry now
  documents the authoring-time call site

## Human Notes Status

- NOT_ADDRESSED: [BUG] Auto-advance milestone UI state leak: in --auto-advance, milestone 2+ starts with all TUI pills already green because completed-stage state carries over. Reset per-milestone TUI completion data on transition in lib/orchestrate_helpers.sh (_run_auto_advance_chain) before re-entering run_complete_loop; reset helper/state likely belongs in lib/tui.sh or lib/tui_ops.sh (_TUI_STAGES_COMPLETE and related stage-progress fields). Add/extend coverage in tests/test_tui_multipass_lifecycle.sh. (Out of scope for this task — task is specifically the acceptance-lint relocation. The note is a separate TUI bug in the auto-advance path; fixing it would be an unrelated orchestration/TUI change.)
- NOT_ADDRESSED: [BUG] GitHub Pages/release workflow checkout fails with `fatal: no url found for submodule path '.claude/worktrees/agent-a049075c' in .gitmodules` because the repo tree contains a committed gitlink at `.claude/worktrees/agent-a049075c` (mode 160000) but no `.gitmodules` entry. Root cause is accidental tracking of a local git worktree under `.claude/worktrees/`. Triage/fix: remove the gitlink from index/history tip (`git rm --cached .claude/worktrees/agent-a049075c`), add `.claude/worktrees/` to `.gitignore`, and add a CI guard that fails if `git ls-files --stage` contains mode 160000 paths outside approved submodules. (Out of scope for this task — task is the acceptance-lint relocation. The note is a separate repo-hygiene / CI fix that also touches committed worktree state; intentionally left for its own milestone so it can be done with the correct destructive-action scrutiny.)
