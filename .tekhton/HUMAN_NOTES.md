# Human Notes
<!-- notes-format: v2 -->
<!-- IDs are auto-managed by Tekhton. Do not remove note: comments. -->

Add your observations below as unchecked items. The pipeline will inject
unchecked items into the next coder run and archive them when done.

Use `- [ ]` for new notes. Use `- [x]` to mark items you want to defer/skip.

Prefix each note with a priority tag so the pipeline can scope runs correctly:
- `[BUG]` — something is broken, needs fixing before new features
- `[FEAT]` — new mechanic or system, architectural work
- `[POLISH]` — visual/UX improvement, no logic changes

## Features

## Bugs
- [x] [BUG] TUI sidecar orphaned after build-gate-failure exit. Repro: run a pipeline that fails the build gate twice (e.g. M03 e2e timeouts on bifl-tracker, 2026-04-25). After `[✗] State saved. Review .tekhton/BUILD_ERRORS.md...` the parent shell exits but `tools/tui.py` keeps running indefinitely; `.claude/tui_sidecar.pid` is left on disk. Two coupled defects: **(A)** `stages/coder.sh:1167` does `write_pipeline_state ...; error "..."; exit 1`, but the `_tekhton_cleanup` EXIT trap (`tekhton.sh:165`) calls `tui_stop` which returns early at `lib/tui.sh:202` (`[[ "$_TUI_ACTIVE" == "true" ]] || return 0`) — at that moment `_TUI_ACTIVE` is not `true` (likely reset by an earlier stage-transition or completion hook), so the sidecar is never killed and the pid file is never removed. **(B)** The watchdog in `tools/tui.py:192-196` is supposed to be the safety net but its conditions (`current_agent_status in ("idle", "paused")` AND `agent_turns_used > 0`) are evaluated against the *last status snapshot the dead parent wrote*. In the orphan case observed, that snapshot has `current_agent_status: "running"` and `agent_turns_used: 0` (build gate is shell-side, never updated post-coder status), so the watchdog can never fire even after 5+ minutes of file staleness. Fix proposal — apply all three for belt-and-suspenders: (1) at every non-wrap-up exit path (`stages/coder.sh:1167` plus any other `write_pipeline_state ...; exit N` site), call `tui_complete "<verdict>"` before exiting so the status file gets `complete:true` and the sidecar exits via its own `if status.get("complete"): break` path; (2) make `tui_stop` resilient to inconsistent state — drop the `_TUI_ACTIVE` early-return when called from cleanup, or alternatively read `tui_sidecar.pid` directly and kill that pid + remove the file regardless of `_TUI_ACTIVE`; (3) loosen the watchdog in `tools/tui.py` to fire on staleness alone (parent-is-dead is the signal) — at minimum add a double-timeout escape hatch that fires after `2 * watchdog_secs` regardless of `current_agent_status`/`agent_turns_used`, since the existing preconditions become unreachable precisely in the case the watchdog was added to handle. Evidence: bifl-tracker session `tekhton_session_WbOATdmX`, parent exit at 09:53:42 EDT, sidecar (PID 124416 on tester host) still running at 10:15+, `tui_status.json` last write 09:53:42 with `current_agent_status:"running"`, `complete:false`, `agent_turns_used:0`.

## Polish
- [ ] [POLISH] In the TUI when wrap-up gets to running final static analyzer the text is so long it pushes all of the timings off the side of the screen in the Stage Timings column. We should either make it ellipsis sooner or make it wrap lines for long lines like that.
