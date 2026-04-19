# Coder Summary

## Status: COMPLETE

## What Was Implemented

M100 — Dynamic Stage Order + TUI Sync. The TUI stage-pill row is now built
dynamically from `get_pipeline_order()` + runtime skip flags, so
`--skip-security`, `DOCS_AGENT_ENABLED=true`, `SKIP_DOCS=true`, and
`PIPELINE_ORDER=test_first` all produce stage pills that reflect the pipeline
actually about to run.

- Added `get_display_stage_order()` to `lib/pipeline_order.sh`. It composes
  the full TUI-visible list: prepends `intake` when `INTAKE_AGENT_ENABLED=true`
  (default), maps internal stage names `test_verify → tester` and
  `test_write → tester-write`, and filters out `security` when
  `SECURITY_AGENT_ENABLED=false` or `SKIP_SECURITY=true`, and `docs` when
  `SKIP_DOCS=true` (`DOCS_AGENT_ENABLED` is already honored upstream in
  `get_pipeline_order()`).
- Replaced the hardcoded `tui_set_context "intake" "scout" "coder" "security"
  "review" "tester"` call in `tekhton.sh` with a call that sources its stage
  list from `get_display_stage_order()` and mirrors the same value into
  `_OUT_CTX[stage_order]` via `out_set_context`.
- Added a runtime-skip refresh call at the top of `_run_pipeline_stages()` in
  `tekhton.sh`: re-runs `get_display_stage_order`, re-publishes the result to
  both the Output Bus and `_TUI_STAGE_ORDER`. This handles the case where
  skip flags are resolved after startup — e.g. `SKIP_SECURITY` set by later
  config processing — so the TUI stays in sync.
- Extended `_tui_stage_order_json()` in `lib/tui_helpers.sh` to fall back to
  `_OUT_CTX[stage_order]` (space-separated string) when `_TUI_STAGE_ORDER` is
  empty. Also wrapped the existing array read in `declare -p` to stay safe
  under `set -u` when `tui_helpers.sh` is sourced alone (without `tui.sh`
  initialising the array).
- Removed the hardcoded fallback stage list from `tools/tui.py`
  (`_empty_status`) and `tools/tui_render.py` (`_build_stage_pills`). The
  renderer now uses numbered placeholders derived from `stage_total` when
  `stage_order` is missing, rather than silently masking regressions with a
  stale six-stage list.
- Extended `tests/test_pipeline_order.sh` with 7 new assertions covering the
  default path, `INTAKE_AGENT_ENABLED=false`, docs insertion, test_first
  mapping, `SKIP_SECURITY`, `SECURITY_AGENT_ENABLED=false`, and `SKIP_DOCS`.
- Extended `tests/test_tui_set_context.sh` with 3 new assertions covering
  `_OUT_CTX[stage_order]` fallback, precedence over the Output Bus when
  `_TUI_STAGE_ORDER` is set, and the all-empty case.
- Updated `tools/tests/test_tui.py`: replaced the now-incorrect
  `test_build_stage_pills_default_order_fallback` test (which asserted six
  pending pills from the removed hardcoded list) with two replacement tests
  that verify (a) empty output when no `stage_order` and no `stage_total`,
  and (b) numbered placeholder pills (`stage-1 … stage-N`) derived from
  `stage_total`.

## Root Cause (bugs only)

Not applicable — this is a feature milestone, not a bug fix. The milestone
document describes the three disagreeing sources of truth for stage order
that this change reconciles.

## Files Modified

- `lib/pipeline_order.sh` — added `get_display_stage_order()` (+47 lines)
- `lib/tui_helpers.sh` — extended `_tui_stage_order_json()` with Output Bus
  fallback and `set -u`-safe array check
- `tekhton.sh` — replaced hardcoded `tui_set_context` stage list near
  startup (lines ~1910-1921) and added a runtime refresh at the top of
  `_run_pipeline_stages()` (lines ~2235-2250)
- `tools/tui.py` — removed hardcoded `stage_order` default in
  `_empty_status()` (now `[]`)
- `tools/tui_render.py` — removed hardcoded fallback in
  `_build_stage_pills`; falls back to numbered placeholders from
  `stage_total` when `stage_order` is absent
- `tests/test_pipeline_order.sh` — 7 new assertions for
  `get_display_stage_order`
- `tests/test_tui_set_context.sh` — 3 new assertions for the
  `_OUT_CTX[stage_order]` fallback
- `tools/tests/test_tui.py` — replaced the default-order-fallback test with
  two tests that cover the new (non-hardcoded) fallback paths

## Docs Updated

None — no public-surface changes in this task. `get_display_stage_order` is
a library helper inside `lib/pipeline_order.sh`; no CLI flags, config keys,
or agent contracts were added or changed. `ARCHITECTURE.md` does not list
`pipeline_order.sh` or its exported functions, so no doc update applies.

## Human Notes Status

No unchecked human notes were injected for this milestone.

## Verification

- `shellcheck -e SC1091` clean on `lib/pipeline_order.sh` and
  `lib/tui_helpers.sh`.
- `bash tests/run_tests.sh`: 395 shell tests pass, 0 fail; 133 Python tests
  pass. `test_tui_no_dead_weight.sh` — which failed on a first pass because
  `_TUI_STAGE_ORDER` was unbound when `tui_helpers.sh` was sourced in
  isolation — passes after the `declare -p` guard was added.
- Acceptance criteria spot-checks via unit tests:
  - standard → `intake scout coder security review tester`
  - `INTAKE_AGENT_ENABLED=false` → `scout coder security review tester`
  - `DOCS_AGENT_ENABLED=true` → `intake scout coder docs security review tester`
  - `PIPELINE_ORDER=test_first` → `intake scout tester-write coder security review tester`
  - `SKIP_SECURITY=true` → `intake scout coder review tester`
  - `SKIP_DOCS=true` with `DOCS_AGENT_ENABLED=true` → `intake scout coder security review tester`
  - `_tui_stage_order_json` reads from `_OUT_CTX[stage_order]` when
    `_TUI_STAGE_ORDER` is empty.
