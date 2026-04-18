# Coder Summary
## Status: COMPLETE

## What Was Implemented

Milestone 97 — TUI Mode (rich.live sidecar). Opt-in full-screen status display
that runs as a decoupled Python sidecar while the shell pipeline executes
unchanged. Falls back silently to the plain M96 output when the venv, `rich`,
or an interactive TTY is unavailable.

- `lib/tui.sh` — sidecar lifecycle (`tui_start`, `tui_stop`, `tui_complete`,
  `tui_update_stage`, `tui_finish_stage`, `tui_update_agent`,
  `tui_append_event`). All update calls are no-ops unless `_TUI_ACTIVE=true`,
  so hook sites can call them unconditionally. Activation gate
  (`_tui_should_activate`) checks `TUI_ENABLED`, TTY, venv, `rich`, and
  `tools/tui.py`. Each failure mode sets a human-readable reason.
- `lib/tui_helpers.sh` — pure-bash JSON builders (`_tui_json_build_status`,
  `_tui_json_stage`, `_tui_recent_events_json`, `_tui_stages_json`,
  `_tui_escape`). Status is written atomically via `.tmp` + `mv`.
- `tools/tui.py` — rich-based sidecar. Polls `tui_status.json` on a tick
  (default 500ms), renders header / stage / pipeline / events panels via
  `rich.live` + `rich.layout`. Exits on `complete=true`, SIGTERM, or SIGINT.
  Renders into an alternate screen (`screen=True, transient=True`) so the
  original terminal scrollback survives.
- Integration wiring: `tekhton.sh` sources `lib/tui.sh` alongside the other
  libs, calls `tui_start` just after the startup banner, calls
  `tui_update_stage` / `tui_finish_stage` around each stage dispatch, and
  invokes `tui_stop` from the EXIT trap. `lib/agent.sh` calls `tui_update_agent`
  from the existing spinner tick. `lib/common.sh` bridges `log` / `warn` /
  `success` / `error` / `header` into the event feed via `_tui_notify` (with
  ANSI stripping). `lib/finalize.sh` registers `_hook_tui_complete` as the last
  finalize hook.
- Config: four keys added in `lib/config_defaults.sh` — `TUI_ENABLED`,
  `TUI_TICK_MS`, `TUI_EVENT_LINES`, `TUI_VENV_DIR` (defaults auto-share
  `REPO_MAP_VENV_DIR`).
- Dependencies: `rich>=13.0.0` added to `tools/requirements.txt`.
- Tests: `tests/test_tui_fallback.sh` (9 assertions — activation gate, no-op
  paths, JSON schema round-trip) and `tools/tests/test_tui.py` (15 pytest
  cases — `_fmt_duration`, `_read_status` edge cases, layout construction with
  full / empty / partial / failed-stage status).

## Files Modified

- `lib/tui.sh` (NEW, 201 lines)
- `lib/tui_helpers.sh` (NEW, 137 lines)
- `tools/tui.py` (NEW, 238 lines)
- `tests/test_tui_fallback.sh` (NEW, 153 lines)
- `tools/tests/test_tui.py` (NEW, 154 lines)
- `tekhton.sh` — sourced `lib/tui.sh`; added `tui_start` after banner;
  `tui_update_stage`/`tui_finish_stage` bracketing stage dispatch; `tui_stop`
  in EXIT trap.
- `lib/common.sh` — added `_tui_strip_ansi` + `_tui_notify`; wired
  `log`/`success`/`warn`/`error`/`header` into the event feed.
- `lib/agent.sh` — wired `tui_update_agent` into the existing spinner tick
  loop (safe no-op when TUI inactive).
- `lib/finalize.sh` — registered `_hook_tui_complete` as the final finalize
  hook.
- `lib/config_defaults.sh` — added `TUI_ENABLED`, `TUI_TICK_MS`,
  `TUI_EVENT_LINES`, `TUI_VENV_DIR` defaults.
- `tools/requirements.txt` — pinned `rich>=13.0.0`.
- `tests/test_finalize_run.sh` — updated hook-count assertions from 24→25 and
  index constants, since `_hook_tui_complete` is a new 25th registered hook.
  Required because my change added a new registered hook; no test weakening.
- `CLAUDE.md` — new files documented under the Repository Layout section;
  four new config keys added to the template variables table.
- `ARCHITECTURE.md` — added `lib/tui.sh` and `lib/tui_helpers.sh` to Layer 3
  module listing.

## Human Notes Status

No human notes block provided for this task.

## Docs Updated

- `CLAUDE.md` — repository layout gained `lib/tui.sh`, `lib/tui_helpers.sh`,
  `tools/tui.py`, `tools/tests/test_tui.py`; template variables table gained
  `TUI_ENABLED`, `TUI_TICK_MS`, `TUI_EVENT_LINES`, `TUI_VENV_DIR`.
- `ARCHITECTURE.md` — Layer 3 module listing gained `lib/tui.sh` and
  `lib/tui_helpers.sh` entries describing public functions and sourcing order.

## Validation

- `shellcheck lib/tui.sh lib/tui_helpers.sh tests/test_tui_fallback.sh` — clean.
- `shellcheck -S warning tekhton.sh lib/common.sh lib/agent.sh lib/finalize.sh
  lib/config_defaults.sh` — only pre-existing SC2034 warnings; no new warnings
  attributable to the TUI integration.
- `bash tests/test_tui_fallback.sh` — 9 passed, 0 failed.
- `python3 -m pytest tools/tests/test_tui.py -q` — 15 passed.
- `bash tests/run_tests.sh` — 386 shell passed / 0 failed; 102 Python passed.
