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

- [x] [BUG] While TUI mode is active, spinner lines like `[tekhton] ⠦ TestTimeout (0m03s, --/10 turns)` intermittently appear at the bottom of the terminal, causing a blinking/flicker effect as they are drawn over the TUI layout. These are the non-TUI CLI spinner lines (produced in `lib/agent_spinner.sh` via `printf` to `/dev/tty`) bleeding through despite TUI being active. Root cause: The non-TUI spinner branch in `_start_agent_spinner` (`lib/agent_spinner.sh:29-30`) is correctly gated on `_TUI_ACTIVE != "true"`, but in `--complete` mode (and potentially in any multi-pass path) `_TUI_ACTIVE` is reset to `false` mid-run. The mechanism: `finalize_run` registers `_hook_tui_complete` as its last hook (`lib/finalize.sh:266`), which calls `out_complete → tui_complete → tui_stop` (`lib/finalize_dashboard_hooks.sh:146-156`), and `tui_stop` sets `_TUI_ACTIVE=false` and kills the sidecar (`lib/tui.sh:176`). After that, the orchestration loop in `lib/orchestrate.sh` re-enters `_run_pipeline_stages` for the next attempt without ever calling `tui_start` again. So all subsequent agent invocations see `_TUI_ACTIVE=false` and the `/dev/tty` spinner fires unguarded for the remainder of the run. Expected behavior: No raw `[tekhton] ⠦ ...` spinner output should appear on the terminal while TUI mode is active. The TUI sidecar should remain up (or be cleanly re-armed) for all pipeline attempts within a single invocation; `tui_stop` should only be called once the outermost run is truly complete. Fix direction: Either (a) move `tui_stop` out of `finalize_run`'s hook chain so it is only called at the top-level teardown path in `tekhton.sh`, and have `finalize_run` only send the per-attempt "complete" event to the already-running sidecar; or (b) have `orchestrate.sh` call `tui_restart`/`tui_start` at the top of each loop iteration when `_TUI_ACTIVE` is false. Option (a) is cleaner — the sidecar lifecycle should match the outer `tekhton.sh` invocation, not individual pipeline attempts.

## Polish
