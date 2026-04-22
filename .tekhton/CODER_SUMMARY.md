# Coder Summary

## Status: COMPLETE

## What Was Implemented

M114 — TUI Renderer + Scout Substage Migration. Three coordinated changes:

1. **Renderer breadcrumb (`tools/tui_render_timings.py`)**
   - `_build_timings_panel` reads the optional `current_substage_label`
     from the status JSON (defaulting to empty string when absent — old
     bash → new Python compatibility).
   - When a substage is active during a `running` agent state, the live
     row label renders as `"{stage} » {substage}"` (e.g. `coder » scout`).
   - The live-row duration continues to use the **parent** stage's
     `stage_start_ts`, so entering a substage does NOT visually reset the
     timer.
   - The turns column blanks while a substage is active (the parent
     counter is stale during the substage run and the substage's own
     count isn't surfaced in this row).
   - The breadcrumb is suppressed during shell-op `working` state, where
     `current_operation` already owns the label slot.

2. **Header/pill row defenses (`tools/tui_render.py`)**
   - No code changes required. Verified that `_build_stage_pills`,
     `_build_active_bar`, `_build_context`, `_build_header_bar`, and
     `_stage_state` all consume `stage_label` / `stage_order` and never
     reference `current_substage_*`. Substage activity therefore cannot
     mutate the pill row or flip the header label to `scout`.

3. **Scout call-site migration (`stages/coder.sh`)**
   - Replaced the `tui_stage_begin "scout"` … `tui_stage_transition
     "scout" "coder"` pair around the `run_agent "Scout"` call with
     `tui_substage_begin "scout"` … `tui_substage_end "scout" "PASS"`.
   - Scout no longer allocates its own stage lifecycle id, never mutates
     `_TUI_STAGE_ORDER`, and never contributes an entry to
     `_TUI_STAGES_COMPLETE`. The outer `tui_stage_begin "coder"` (in
     `tekhton.sh`) remains the single owner of the coder pipeline-stage
     lifecycle.
   - `tui_stage_transition` in `lib/tui_ops.sh` is left intact for the
     architect-remediation caller (deferred to M116).

4. **Renderer tests (`tools/tests/test_tui_render_timings.py`)**
   - Added a `TestSubstageBreadcrumb` class with six new cases covering:
     breadcrumb rendering, blank turns column during substage, parent
     timer continuity across the substage boundary, missing-key
     tolerance, empty-label edge case, and breadcrumb suppression in
     `working` state.

## Root Cause (bugs only)

N/A — feature work, not a bug fix.

## Files Modified

| File | Notes |
|------|-------|
| `tools/tui_render_timings.py` | M114 substage breadcrumb + blank turns + missing-key tolerance |
| `stages/coder.sh` | Scout migrated to substage API (`tui_substage_begin/end`) |
| `tools/tests/test_tui_render_timings.py` | Added `TestSubstageBreadcrumb` (6 new tests) |
| `.tekhton/CODER_SUMMARY.md` | This summary |

No new files were created. `tools/tui_render.py` is listed in the milestone's
Files Modified table only as "verify no regression"; verification confirmed
no code change is needed.

## Docs Updated

None — no public-surface changes in this task. The scout migration is an
internal call-site change; the substage API itself was added (and its
contract documented) in M113. The renderer change is an internal display
behavior with no new config keys, CLI flags, or exported functions. No
README or `docs/` page documents the Python TUI renderer's internal label
formatting.

## Acceptance Criteria — Self-Verification

- [x] `tui_status.json` carries `current_stage_label="coder"` and
      `current_substage_label="scout"` simultaneously while scout runs.
      Verified by reading `lib/tui_helpers.sh::_tui_json_build_status`,
      which emits both fields independently from `_TUI_CURRENT_STAGE_LABEL`
      and `_TUI_CURRENT_SUBSTAGE_LABEL`. The substage API touches only the
      latter; the parent stage label remains untouched.
- [x] Live row renders `coder » scout` while scout is active.
      (`test_substage_breadcrumb_in_live_row`.)
- [x] Live-row duration uses parent `stage_start_ts`; no visible reset.
      (`test_parent_timer_continues_across_substage_boundary` — parent
      shows "2m" elapsed while substage is only 5s old.)
- [x] Turns column blank while substage is active; reverts to parent
      `--/max` after substage ends.
      (`test_substage_blanks_turns_column` and
      `test_missing_substage_keys_tolerated`.)
- [x] `stages_complete` never contains a `scout` entry.
      Mechanically guaranteed: `tui_substage_end` does not call
      `tui_finish_stage`. The M113 contract test
      `tests/test_tui_substage_api.sh` already asserts no row is added.
- [x] Pill row identical to pre-M114 (no scout pill).
      `tui_substage_begin` does not mutate `_TUI_STAGE_ORDER`. Verified by
      reading `lib/tui_ops_substage.sh:27-35`.
- [x] Header continues to show `coder`; never flips to `scout`.
      `tui_substage_begin` does not call `tui_update_stage` and does not
      assign to `_TUI_CURRENT_STAGE_LABEL`.
- [x] Python renderer tolerates missing `current_substage_label` /
      `current_substage_start_ts`.
      `.get(...) or ""` default; `test_missing_substage_keys_tolerated`.
- [x] `stages/architect.sh`'s `tui_stage_transition` call unchanged.
      Confirmed via grep — only edit was in `stages/coder.sh`.
- [x] All `tests/test_tui_stage_wiring.sh` tests still pass.
      Full bash suite: 423 passed, 0 failed.
- [x] New renderer test cases pass.
      `tools/tests/test_tui_render_timings.py`: 32 passed including 6 new.
- [x] Shellcheck clean for `stages/coder.sh`.
      `shellcheck -x stages/coder.sh` → 0 warnings, only the pre-existing
      SC1091 sourcing info note for the `coder_prerun.sh` include.

## Test Results

- `bash tests/run_tests.sh`: shell 423/423 pass, python 183/183 pass.
- `python3 -m pytest tools/tests/test_tui_render_timings.py`: 32/32 pass.
- `shellcheck tekhton.sh lib/*.sh stages/*.sh`: clean (only pre-existing
  SC1091 sourcing-info note for `lib/pipeline_order.sh`).

## Human Notes Status

No `HUMAN_NOTES.md` items were addressed — there were none in scope for
M114. The clarifications block in the prompt contained answers to prior
unrelated intake questions (Watchtower dashboard, NON_BLOCKING_LOG,
init/plan circularity, HUMAN_NOTES inconsistency) which are not part of
this milestone.

## Observed Issues (out of scope)

- `stages/coder.sh` is 1180 lines (over the 300-line ceiling). This is a
  pre-existing condition — the file was already over 1190 lines before
  M114 across multiple completed milestones (M107, M110). My M114 edit
  reduces the file by ~10 lines. Refactoring it to <300 lines is a
  multi-milestone cleanup well beyond the scope of M114.
- The header `_build_active_bar` (in `tools/tui_render.py`) keeps the
  parent stage label `coder` while scout runs but its turn counter shows
  scout's progress (because `tui_update_agent` overwrites the parent's
  `_TUI_AGENT_TURNS_USED`/`_TUI_AGENT_TURNS_MAX`). This is consistent with
  M114 acceptance ("header shows coder continuously"), but a future
  milestone may want to mirror the timings-row turn-blanking behavior in
  the active bar for consistency. Flagging for consideration in M115/M117.
