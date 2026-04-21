# Coder Summary
## Status: COMPLETE

## What Was Implemented

TUI sidecar lifecycle is now scoped to the outer `tekhton.sh` invocation rather
than individual pipeline passes, so `--complete`, `--fix-nb`, `--fix-drift`, and
`--human --complete` modes no longer leak `[tekhton] ⠦ ...` spinner lines
through `/dev/tty` between passes.

Changes:

1. **`lib/finalize_dashboard_hooks.sh`** — `_hook_tui_complete` no longer calls
   `out_complete` (which cascaded to `tui_complete → tui_stop` and flipped
   `_TUI_ACTIVE=false` mid-run). The per-pass hook now:
   - Closes the `wrap-up` stage pill via `tui_stage_end`.
   - Emits a `Pass complete: SUCCESS|FAIL` summary event to the ring buffer
     via `tui_append_summary_event` so users still see the per-pass outcome
     in the events panel.
   - Leaves `_TUI_ACTIVE=true` and the sidecar PID alive.

2. **`tekhton.sh`** — Added a single top-level `out_complete "SUCCESS"` call
   at the bottom of the file, after all dispatch branches
   (`_run_human_complete_loop`, `run_complete_loop`, `_run_fix_nonblockers_loop`,
   `_run_fix_drift_loop`, plain single-run). This is the only site that
   triggers the hold-on-complete + `tui_stop` sequence under normal exit.
   The cleanup `trap` at the top of `tekhton.sh` still calls `tui_stop` as a
   safety net for crashes.

3. **`tekhton.sh`** — Removed the two now-redundant `tui_start` re-arm calls
   inside `_run_fix_nonblockers_loop` and `_run_fix_drift_loop`. Those calls
   existed to resurrect the sidecar that `_hook_tui_complete` had just killed;
   since the sidecar is no longer killed per pass, re-arming would double-start.

4. **`tests/test_out_complete.sh`** — Rewrote Part 2 to cover the new contract:
   `_hook_tui_complete` must call `tui_stage_end "wrap-up"` with the pass verdict
   and `tui_append_summary_event` with `"Pass complete: <verdict>"`, and must
   NOT call `out_complete`. Tests 6–10 verify both success and failure paths.

5. **`tests/test_tui_multipass_lifecycle.sh`** (NEW) — Regression test for the
   reported bug. Simulates multi-pass finalize_run() cycles without spawning a
   real Python sidecar (sets `_TUI_ACTIVE=true` directly). Verifies:
   - `_TUI_ACTIVE` stays `true` after one, then three sequential hook calls.
   - `_TUI_COMPLETE` is not flipped mid-loop.
   - Each pass appends exactly one summary event of the correct level.
   - Mixed success/fail verdicts produce correct `success`/`error` levels.
   - Hook is a no-op when TUI was never active (doesn't resurrect it).

## Root Cause (bugs only)

`finalize_run()` registered `_hook_tui_complete` as its last hook. That hook
called `out_complete → tui_complete → tui_stop`, which set `_TUI_ACTIVE=false`
and SIGKILLed the sidecar process. In multi-pass modes, the outer orchestrator
(`run_complete_loop`, `_run_human_complete_loop`, `_run_fix_nonblockers_loop`,
`_run_fix_drift_loop`) called `_run_pipeline_stages` + `finalize_run` repeatedly.
After the first pass, `_TUI_ACTIVE=false`, so `_start_agent_spinner` in
`lib/agent_spinner.sh:29-30` took the non-TUI branch and wrote `[tekhton] ⠦ ...`
spinner frames directly to `/dev/tty`, which bled through the
(possibly-restarted) TUI layout and caused the blinking/flicker effect.

The fix inverts the lifecycle: the sidecar is owned by the outermost
`tekhton.sh` process, not by individual `finalize_run()` passes.

## Files Modified

- `lib/finalize_dashboard_hooks.sh` — `_hook_tui_complete` no longer triggers `out_complete`
- `tekhton.sh` — dropped per-loop `tui_start` calls; added one top-level `out_complete` at EOF
- `tests/test_out_complete.sh` — updated contract (tests 6–10)
- `tests/test_tui_multipass_lifecycle.sh` (NEW) — regression test for multi-pass TUI lifecycle

## Docs Updated

None — no public-surface changes in this task. `_hook_tui_complete` is internal,
the TUI contract is unchanged from the user's perspective (spinner never leaks
on `/dev/tty` while TUI is active).

## Human Notes Status

No human notes injected.
