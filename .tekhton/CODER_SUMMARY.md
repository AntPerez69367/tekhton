# Coder Summary

## Status: COMPLETE

## What Was Implemented

M98 TUI Redesign — Layout, Run Context, Logo Animation & Completion Hold.

- **§1 Spinner bleed fix** — `_TUI_ACTIVE` is now `export`-ed in `lib/tui.sh` so
  child processes (test harnesses, plan batch runs) can read the sidecar-active
  signal. The spinner subshell in `lib/plan_batch.sh` now guards its
  `/dev/tty` write behind `[[ "${_TUI_ACTIVE:-false}" != "true" ]]` so it stops
  writing raw text when the rich alternate-screen buffer owns the terminal.

- **§2 Layout consolidation** — `tools/tui.py` replaced the 4-panel layout
  (stage/pipeline/agent/events) with a 2-zone layout: a fixed `size=8` header
  and a `ratio=1` events panel that fills the rest of the terminal. The two
  now-dead helpers `_build_stage_panel` and `_build_pipeline_panel` were
  removed; their data was folded into the new header bar.

- **§3 Header bar** — New `_build_header_bar` renders a Panel with two
  columns: a 14-char logo column and a ratio-1 context grid. Context grid
  has five rows: title (TEKHTON + milestone + title), meta (run_mode · Pass
  N/M · cli_flags), task line, stage-pills row, and active-stage bar
  (label, model, progress bar, turns, elapsed, spinner).

- **§4 Run context wiring** — New `tui_set_context RUN_MODE FLAGS STAGE…`
  function in `lib/tui.sh` populates three new globals (`_TUI_RUN_MODE`,
  `_TUI_CLI_FLAGS`, `_TUI_STAGE_ORDER`). `tekhton.sh` derives these
  immediately before `tui_start` from the parsed CLI flags
  (`--auto-advance`, `--skip-audit`, `--skip-security`, `--skip-docs`,
  `--human`, `--no-commit`, `--start-at`) and milestone/fix/complete mode
  bools. New JSON fields (`run_mode`, `cli_flags`, `stage_order`) are
  emitted by `_tui_json_build_status`. `TUI_EVENT_LINES` default changed
  8→60 (ring-buffer depth; display height is terminal-driven).

- **§5 Logo animation** — Introduced a 5-row × 12-char Unicode block-art
  arch logo (`_ARCH_WALLS` + `_LOGO_FRAMES` in `tools/tui_render.py`).
  Animated 3-frame cycle (ghost → floating → seated keystone) driven by
  `int(time.time() * 0.6) % 3` when `current_agent_status == running`.
  Idle state collapses to the seated-keystone frame in dim white; complete
  state uses gold styling. A 5-line ASCII fallback (`_SIMPLE_LOGO_LINES`)
  is selected via `TUI_SIMPLE_LOGO=true` and passed to `tools/tui.py` via
  `--simple-logo`.

- **§6 Hold-on-complete** — `tui_complete` now polls `kill -0 $_TUI_PID`
  in 100ms ticks up to `TUI_COMPLETE_HOLD_TIMEOUT=120` seconds, allowing
  the sidecar to run its final hold before teardown. The new
  `tools/tui_hold.py` module exits Live context, prints a
  `console.rule("Tekhton — Run Complete")` banner, renders the verdict +
  elapsed + milestone + task summary, dumps the full event log in normal
  scroll, and waits on `/dev/tty` for Enter. Non-interactive envs
  (no `/dev/tty`) fall back to a 3-second pause.

- **§7 Status JSON schema** — Added `run_mode`, `cli_flags`, `stage_order`
  (string array), and retained `stage_start_ts` for wall-clock elapsed
  calculation in the active-stage bar.

## Root Cause (bugs only)

N/A — feature milestone (M98).

## Files Modified

- `lib/tui.sh` — `export _TUI_ACTIVE`; new `tui_set_context` fn; run-context
  globals (`_TUI_RUN_MODE`, `_TUI_CLI_FLAGS`, `_TUI_STAGE_ORDER`);
  `tui_start` builds arg array and accepts `--simple-logo`; `tui_complete`
  waits up to `TUI_COMPLETE_HOLD_TIMEOUT` for the sidecar; ring-buffer
  fallback default aligned to 60.
- `lib/tui_helpers.sh` — new `_tui_stage_order_json` helper; three new
  JSON fields (`run_mode`, `cli_flags`, `stage_order`) in
  `_tui_json_build_status`.
- `lib/plan_batch.sh` — spinner subshell now guards against writing to
  `/dev/tty` when the TUI owns the terminal.
- `lib/config_defaults.sh` — `TUI_EVENT_LINES` default 8→60; new
  `TUI_COMPLETE_HOLD_TIMEOUT` (120) and `TUI_SIMPLE_LOGO` (false).
- `tekhton.sh` — derive run_mode / cli_flags / stage_order and call
  `tui_set_context` before `tui_start`.
- `tools/tui.py` — rewritten as thin main (~150 lines): signal handling,
  status read, 2-zone layout construction, Live loop, hand-off to
  `_hold_on_complete`. Re-exports render helpers for test discovery.
- `tools/tui_render.py` — new file: `_fmt_duration`, logo builders, stage
  pills, active-stage bar, header bar, events panel (~280 lines).
- `tools/tui_hold.py` — new file: `_hold_on_complete` + verdict styling
  (~70 lines).
- `tools/tests/test_tui.py` — refreshed `_sample_status` to include new
  fields; replaced panel tests with tests for header bar, 3-frame logo
  animation, idle/complete logo, simple logo, panel-removal guard, and
  a smoke test for `_hold_on_complete` in non-interactive mode.
- `CLAUDE.md` — registered `tools/tui_render.py` and `tools/tui_hold.py`
  in the Repository Layout; updated `TUI_EVENT_LINES` description; added
  rows for `TUI_COMPLETE_HOLD_TIMEOUT` and `TUI_SIMPLE_LOGO`.

## Human Notes Status

No active human notes for this milestone.

## Architecture Change Proposals

None. This milestone is additive (new context fields, new sidecar module
split) and refactors only the TUI rendering path. No cross-cutting contract
changes.
