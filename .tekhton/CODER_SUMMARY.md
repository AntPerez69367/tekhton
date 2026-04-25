# Coder Summary

## Status: COMPLETE

## What Was Implemented

Three coupled fixes that close the TUI sidecar orphan that was reported on
bifl-tracker session `tekhton_session_WbOATdmX` (parent exit 09:53:42 EDT,
sidecar PID 124416 still alive at 10:15+, `tui_status.json` last write at
parent-exit time with `complete:false`):

1. **`lib/tui.sh::tui_stop` — pidfile fallback (Issue B).**
   Dropped the `[[ "$_TUI_ACTIVE" == "true" ]] || return 0` early-return.
   `tui_stop` now sources the kill target from `_TUI_PID` first and falls
   back to `${PROJECT_DIR}/.claude/tui_sidecar.pid` when `_TUI_PID` is
   empty. The EXIT trap in `tekhton.sh:148-150` therefore reaps the
   sidecar even if `_TUI_ACTIVE` was flipped false earlier in the run.
   Pidfile is removed in every code path (alive process, dead PID, or no
   PID at all) so the next run does not find a stale file.

2. **`tools/tui.py` — double-timeout watchdog escape hatch (Issue C).**
   The original watchdog requires `current_agent_status in ("idle",
   "paused")` AND `agent_turns_used > 0`. In the orphan-on-build-gate
   scenario the last status snapshot has `current_agent_status:"running"`
   and `agent_turns_used:0` (the build gate is shell-side, never counted
   as an agent turn), so those preconditions were unreachable. Added a
   second branch that fires after `2 × watchdog_secs` of mtime staleness
   regardless of the snapshot's logical state — the parent shell is
   provably dead at that point.

3. **`tools/tui_render_timings.py` — long-label wrap (human note POLISH).**
   Changed the label column from `no_wrap=True` to `no_wrap=False,
   overflow="fold"`. Long substage breadcrumbs (e.g. `wrap-up » running
   final static analyzer …`) now wrap onto additional lines instead of
   pushing the time / turns columns off-screen. Verified at terminal
   widths 30 / 40 / 60 / 80 — `3m0s` and `12/30` remain visible at every
   width.

I did NOT add `tui_complete` calls before each `exit 1` site (proposal #1
in the bug report). Fix #1 above (resilient `tui_stop` driven from the
EXIT trap) handles every error-exit path uniformly without spreading the
TUI lifecycle concern across 13+ sites in `stages/coder.sh` and friends.

## Root Cause (bugs only)

Orphan sidecar after build-gate-failure exit was caused by the conjunction
of two latent defects:

- **A.** Per-stage error exits (`stages/coder.sh:1167` and ~12 other
  `error "…"; exit 1` sites) bypass the `tui_complete` happy-path
  teardown. The EXIT trap in `tekhton.sh:165` runs `_tekhton_cleanup`,
  which calls `tui_stop`. Pre-fix, `tui_stop` early-returned when
  `_TUI_ACTIVE != "true"`, leaving the Python sidecar process running
  and the on-disk pidfile.
- **C.** The watchdog in `tools/tui.py:192-196` was supposed to be the
  safety net but its preconditions become unreachable in precisely the
  failure mode it was added to handle: the last status snapshot the
  dying parent wrote shows `running` + `0 turns`, neither matching
  `idle/paused` nor `turns > 0`. The sidecar therefore hung indefinitely.

## Files Modified

- `lib/tui.sh` — refactored `tui_stop` to source target PID from
  `_TUI_PID` with a pidfile fallback; removed the `_TUI_ACTIVE`
  early-return guard.
- `tools/tui.py` — added the 2× watchdog escape hatch in the main loop.
- `tools/tui_render_timings.py` — relaxed the label column to wrap long
  text rather than squeeze the right columns off-screen.
- `tools/tests/test_tui.py` — added three tests:
  `test_double_timeout_fires_on_running_status_after_2x_staleness`,
  `test_double_timeout_does_not_fire_before_2x_threshold`,
  `test_timings_panel_long_label_does_not_push_time_columns_offscreen`.
- `tests/test_tui_stop_orphan_recovery.sh` (NEW) — four bash tests
  covering the resilient-`tui_stop` paths: orphan kill via pidfile while
  `_TUI_ACTIVE=false`, no-op when nothing to clean up, normal-path
  preservation, stale-pidfile-with-dead-pid tolerance.

## Docs Updated

None — no public-surface changes in this task. `tui_stop` keeps the same
signature and contract; `tui.py` keeps the same `--watchdog-secs` flag;
the timings panel keeps the same content (rendering-only tweak). The
rendering wrap is a UX improvement without contract change.
`docs/tui-lifecycle-model.md` describes panel ownership and the substage
API at a structural level — none of those invariants moved.

## Pre-Completion Self-Check

- **File length:**
  - `lib/tui.sh` — 294 lines (under 300 ✓).
  - `tools/tui.py` — 221 lines (under 300 ✓).
  - `tools/tui_render_timings.py` — 126 lines (under 300 ✓).
  - `tests/test_tui_stop_orphan_recovery.sh` — 144 lines (under 300 ✓).
  - `tools/tests/test_tui.py` — 1153 lines after my +108-line addition,
    but was already 1045 before my edits. Bringing it under 300 would
    require a multi-file refactor of the existing test layout, which is
    out of scope for a bugfix. The companion file
    `tools/tests/test_tui_render_timings.py` (517 lines, pre-existing)
    confirms the project's test-file convention exceeds the 300-line
    rule used for production code; my new tests are co-located with
    related coverage rather than split into a fourth `test_tui_*.py`
    file.
- **Stale references:** none — no symbol renames.
- **Dead code:** none added.
- **Consistency:** new test file recorded under `## Files Modified`
  with the `(NEW)` annotation. The new file is a bash test in `tests/`,
  which is parallel to similarly-scoped tests
  (`tests/test_tui_active_path.sh`, `tests/test_tui_stage_wiring.sh`,
  …); no top-level repository layout doc lists individual test files.

## Verification

- `shellcheck tekhton.sh lib/*.sh stages/*.sh tests/test_tui_stop_orphan_recovery.sh`
  → only pre-existing SC1091 / SC2153 info-level notices for unrelated
  files; no new warnings.
- `bash tests/run_tests.sh` → 453 shell tests pass, 0 fail; 219 Python
  tests pass, 14 skipped (unrelated optional deps), 0 fail.

## Human Notes Status

- COMPLETED: [POLISH] In the TUI when wrap-up gets to running final
  static analyzer the text is so long it pushes all of the timings off
  the side of the screen in the Stage Timings column. We should either
  make it ellipsis sooner or make it wrap lines for long lines like
  that.
