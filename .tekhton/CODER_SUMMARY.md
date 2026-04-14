# Coder Summary
## Status: COMPLETE
## What Was Implemented

Milestone 82: Milestone Progress CLI & Run-Boundary Guidance

1. **`--milestones` subcommand** (tekhton.sh) — New early-exit command that renders
   progress bar, done/pending sections, and a run command for the next milestone.
   Supports `--all` (include completed) and `--deps` (show dependency edges) flags.

2. **`lib/milestone_progress.sh`** (NEW) — Contains `_render_milestone_progress()`,
   `_compute_next_action()`, and `_diagnose_recovery_command()`.

3. **`lib/milestone_progress_helpers.sh`** (NEW) — Extracted rendering helpers:
   `_render_progress_dag()`, `_render_progress_inline()`, `_render_progress_bar()`,
   `_render_milestone_line()`.

4. **Enriched `--status`** — Milestone progress section appended when MANIFEST.cfg
   exists, showing done/total count, current milestone, and next milestone.

5. **Finalization next-action line** (lib/finalize_display.sh) — Appends
   `_compute_next_action()` output after the action items display.

6. **Diagnose recovery command** (lib/diagnose_output.sh) — Both the markdown report
   and terminal summary now include a concrete `tekhton --start-at ...` recovery
   command derived from `_diagnose_recovery_command()`.

7. **`NO_COLOR` support** (lib/common.sh) — Color variables blanked when
   `NO_COLOR=1` is set, per https://no-color.org/.

8. **UTF-8/ASCII symbol detection** — All new output uses `_is_utf8_terminal()` to
   select between UTF-8 symbols (✓, ▶, ━) and ASCII fallbacks (+, >, =).

9. **DAG-disabled fallback** — When `MILESTONE_DAG_ENABLED=false`, `--milestones`
   falls back to `parse_milestones_auto()` with a flat list and a note about
   dependency tracking being unavailable.

## Root Cause (bugs only)
N/A — feature milestone

## Files Modified
- `tekhton.sh` — `--milestones`/`--all`/`--deps` arg parsing, early-exit handler, `--status` milestone section, sourcing of new lib files
- `lib/milestone_progress.sh` (NEW) — Main API: `_render_milestone_progress`, `_compute_next_action`, `_diagnose_recovery_command`
- `lib/milestone_progress_helpers.sh` (NEW) — Rendering helpers extracted for 300-line ceiling
- `lib/common.sh` — `NO_COLOR=1` support (5 lines)
- `lib/diagnose_output.sh` — Recovery command in report + terminal summary
- `lib/finalize_display.sh` — Next-action guidance after action items
- `tests/test_milestone_progress_display.sh` (NEW) — 9 assertions covering progress rendering
- `tests/test_next_action_computation.sh` (NEW) — 8 assertions covering decision table
- `tests/test_diagnose_recovery_command.sh` (NEW) — 8 assertions covering recovery command
- `CLAUDE.md` — Repository layout updated with new files
- `ARCHITECTURE.md` — Layer 3 library docs updated with new files

## Docs Updated
- `CLAUDE.md` — Added `milestone_progress.sh` and `milestone_progress_helpers.sh` to repository layout
- `ARCHITECTURE.md` — Added library documentation for both new files
- `tekhton.sh` — Updated usage/help text with `--milestones`, `--all`, `--deps` flags

## Human Notes Status
No human notes for this milestone.

## Observed Issues (out of scope)
- `lib/common.sh` (334 lines) — Pre-existing 300-line ceiling violation (was 329 before M82)
- `lib/diagnose_output.sh` (343 lines) — Pre-existing 300-line ceiling violation (was 318 before M82)
