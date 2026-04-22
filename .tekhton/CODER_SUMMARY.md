# Coder Summary

## Status: COMPLETE

## What Was Implemented

Addressed all 12 open non-blocking notes in `.tekhton/NON_BLOCKING_LOG.md`. Several
notes were duplicates (M115/M116 restated the same `run_op` ordering issue;
M110/M111 restated the same path-traversal guard request; M110/M112 restated the
same `emit_event` guard idiom). Two notes (5 and 10/11) were informational and
required no code change — the first acknowledges a harmless convention, and the
second was already fixed in M113 (ce43fb8) before the notes were recorded. All
other items produced code or test changes.

### Code changes

1. **`run_op` ordering (notes 1 and 2)** — `lib/tui_ops.sh:run_op` now sets
   `_TUI_AGENT_STATUS="idle"` **before** calling `tui_substage_end` so the
   substage-end flush already carries the final idle status, removing the
   transitional "Working…" frame.

2. **`tui_substage_begin` unused MODEL arg (note 6)** — `lib/tui_ops_substage.sh`
   now binds `local _model="${2:-}"` with a `: "$_model"` reference. Future
   readers see the arg is intentional and linters no longer flag it.

3. **`tui_substage_end` unused LABEL/VERDICT args (note 7)** — same treatment
   as note 6: explicit `local _label` and `local _verdict` binds with a
   `: "$_label" "$_verdict"` reference.

4. **`tui_stage_end` triple-write consolidation (note 8)** — added
   `_TUI_SUPPRESS_WRITE` semaphore in `lib/tui.sh` (checked at top of
   `_tui_write_status`). `tui_stage_end` now bumps the semaphore before the
   auto-close + finish_stage path and issues a single coherent status-file
   write at the end instead of three.

5. **Path-traversal guard in `_split_flush_sub_entry` (notes 9 and 12)** —
   `lib/milestone_split_dag.sh` now rejects any `sub_file` value with a `/`
   separator immediately before the write, independent of `_slugify`'s current
   behaviour. An `error` log is emitted and the flush returns 1.

### Test changes

6. **`test_substage_blanks_turns_column` (note 3)** — added a direct positive
   assertion on the grid's live-row turns cell (`grid.columns[2]._cells[-1]`)
   with plain-text extraction, complementing the existing `--/50 not in`
   inverse check.

7. **`test_parent_timer_continues_across_substage_boundary` (note 4)** —
   replaced the `panel_str.split("(", 1)[0]` substring check with direct
   inspection of the live-row time cell (`grid.columns[1]._cells[-1]`). No
   longer vulnerable to false negatives if rich ever injects a `(` into the
   label column.

### Informational items (no code change)

8. **Double-guard acknowledgement (note 5)** — the `declare -f tui_substage_begin`
   guard in `stages/coder.sh:236` is slightly redundant given the internal
   `_TUI_ACTIVE` gate, but it follows the established codebase convention and
   matches how every other lib function call is guarded. No change required.

9. **`emit_event` guard idiom (notes 10 and 11)** — verified both
   `stages/coder_prerun.sh:69` and `stages/tester_fix.sh:164` already use
   `declare -f emit_event &>/dev/null`. The notes were filed against M112
   state; the fix landed in M113 (commit ce43fb8) before the non-blocking
   notes were collected. Nothing to do.

## Root Cause (bugs only)

N/A — all items were cleanup / quality-of-implementation notes, not bugs.

## Files Modified

- `lib/tui.sh` — added `_TUI_SUPPRESS_WRITE` global and the semaphore check
  inside `_tui_write_status`.
- `lib/tui_ops.sh` — `run_op` now sets idle before `tui_substage_end`;
  `tui_stage_end` wraps intermediate mutations in the write-suppression
  semaphore and issues a single final write.
- `lib/tui_ops_substage.sh` — `tui_substage_begin` binds the unused MODEL
  arg; `tui_substage_end` binds the unused LABEL and VERDICT args.
- `lib/milestone_split_dag.sh` — `_split_flush_sub_entry` rejects filenames
  containing `/` before writing.
- `tools/tests/test_tui_render_timings.py` — strengthened
  `test_substage_blanks_turns_column` and
  `test_parent_timer_continues_across_substage_boundary` with direct
  inspection of the rich grid cells instead of substring checks on the
  rendered string.

## Observed Issues (out of scope)

- `tools/tests/test_tui_render_timings.py` is 512 lines (was 480 before my
  ~30-line additions), exceeding the 300-line ceiling. Pre-existing. Splitting
  this test file is a separate cleanup concern and outside the scope of a
  non-blocking-notes sweep.

## Docs Updated

None — no public-surface changes in this task. All modifications are internal
to the TUI status-writer flow, substage API bookkeeping, the milestone-split
helper, and test assertions. No config keys, CLI flags, or exported contracts
changed.

## Human Notes Status

- Note 1 (run_op idle ordering, M116 restatement) — COMPLETED (lib/tui_ops.sh).
- Note 2 (run_op idle ordering, M115) — COMPLETED (same fix as note 1).
- Note 3 (test_substage_blanks_turns_column strengthening) — COMPLETED
  (tools/tests/test_tui_render_timings.py).
- Note 4 (test_parent_timer_continues_across_substage_boundary strengthening)
  — COMPLETED (tools/tests/test_tui_render_timings.py).
- Note 5 (double-guard acknowledgement) — COMPLETED (informational; no change
  needed; documented above).
- Note 6 (tui_substage_begin MODEL arg) — COMPLETED (lib/tui_ops_substage.sh).
- Note 7 (tui_substage_end LABEL/VERDICT args) — COMPLETED
  (lib/tui_ops_substage.sh).
- Note 8 (tui_stage_end triple-write consolidation) — COMPLETED (lib/tui.sh +
  lib/tui_ops.sh).
- Note 9 (path-traversal guard, M110 restatement) — COMPLETED
  (lib/milestone_split_dag.sh).
- Note 10 (emit_event guard idiom, M110 restatement) — COMPLETED
  (already fixed in M113; verified).
- Note 11 (emit_event guard idiom, M112 restatement) — COMPLETED
  (already fixed in M113; verified).
- Note 12 (path-traversal guard, M111 restatement) — COMPLETED (same fix as
  note 9).
