# Coder Summary

## Status: COMPLETE

## What Was Implemented

M107 wires every pipeline stage into the M106 TUI protocol API
(`tui_stage_begin` / `tui_stage_end`) so the sidecar's pill bar reflects
real stage progression instead of showing grey/missing pills for the
intake, scout, rework, and wrap-up stages.

Changes:

1. **`lib/pipeline_order.sh`** — `get_display_stage_order` now always
   suffixes `wrap-up` as the final pill; finalize activates it.
2. **`tekhton.sh`** —
   - Main pipeline loop before/after blocks now route through
     `get_stage_display_label` and call `tui_stage_begin` /
     `tui_stage_end` (replacing the raw-internal-name path).
   - Intake pre-stage is bracketed with explicit `tui_stage_begin
     "intake"` / `tui_stage_end "intake" ... "$_intake_verdict"` so the
     intake pill activates even though intake runs before the main loop.
3. **`stages/coder.sh`** — scout `run_agent` call is bracketed with
   `tui_stage_begin "scout"` / `tui_stage_end "scout"` so the scout
   pill ticks inside `run_stage_coder` (scout is intentionally
   suppressed as a standalone pipeline-loop stage).
4. **`stages/review.sh`** — both rework paths (Sr coder and Jr-only)
   bracket their `run_agent` calls with `tui_stage_begin "rework"` /
   `tui_stage_end "rework"` using the model that actually ran. Two
   cycles produce one deduped pill plus two `stages_complete` entries.
   The Jr-after-Sr pill-sharing path is deliberately left unwired per
   spec.
5. **`lib/finalize.sh`** — `finalize_run` now emits
   `tui_stage_begin "wrap-up"` as its first action, covering every
   finalize call site with a single hook.
6. **`lib/finalize_dashboard_hooks.sh`** — `_hook_tui_complete` now
   emits `tui_stage_end "wrap-up" ... "$verdict"` just before
   `out_complete`, so all commit/archive/version-bump hooks have
   finished before the wrap-up pill closes and the sidecar flips into
   hold-on-complete.
7. **`tests/test_tui_stage_wiring.sh`** (new) — 21 integration checks:
   intake label emission, `test_verify` raw-name regression guard,
   two-rework-cycles → 1 pill + 2 completions, wrap-up verdict
   propagation, `get_display_stage_order` ends with `wrap-up` across
   4 configurations (standard / test_first / security disabled /
   docs enabled), and `get_stage_display_label` correctness for all 11
   canonical stage names.

## Root Cause (bugs only)

N/A — this is a wiring milestone, not a bug fix. The M106 protocol API
was already in place; stages simply had no call sites yet.

## Files Modified

- `lib/pipeline_order.sh` — append `wrap-up` to display order (1 line).
- `tekhton.sh` — intake pre-stage wiring + pipeline loop
  display-label routing (3 edits).
- `stages/coder.sh` — bracket scout `run_agent` with tui stage calls.
- `stages/review.sh` — bracket both rework paths with tui stage calls.
- `lib/finalize.sh` — `tui_stage_begin "wrap-up"` at top of
  `finalize_run`.
- `lib/finalize_dashboard_hooks.sh` — `tui_stage_end "wrap-up"` in
  `_hook_tui_complete` before `out_complete`.
- `tests/test_tui_stage_wiring.sh` — NEW, 236-line integration test.
- `tests/test_pipeline_order.sh` — updated Phase 12 expectations to
  include the trailing `wrap-up` entry now appended by
  `get_display_stage_order`.

## Docs Updated

None — no public-surface changes. All changes are internal wiring
between the pipeline and the pre-existing M106 TUI protocol API.

## Human Notes Status

No human notes in scope for this milestone.
