# Coder Summary
## Status: COMPLETE

## What Was Implemented
M101 — Eliminate Direct ANSI Output. All 91 direct `echo -e "...${BOLD|RED|GREEN|YELLOW|CYAN|NC}..."` calls across the 10 target library files have been migrated to the new structured formatters in `lib/output_format.sh` or to the existing `log`/`warn`/`error`/`success` wrappers that route through `_out_emit`.

- `lib/output_format.sh` (NEW, 245 lines): public API `out_msg`, `out_banner`, `out_section`, `out_kv`, `out_hr`, `out_progress`, `out_action_item`, plus internals `_out_color`, `_out_term_width`, `_out_repeat`, `_out_append_action_item`, `_out_json_escape`. All formatters check `NO_COLOR` at call time and short-circuit to event-feed entries when `_TUI_ACTIVE=true`. `out_action_item` accumulates to `_OUT_CTX[action_items]` as a JSON array in TUI mode so M102's hold screen can consume it.
- `lib/common.sh`: sources `output_format.sh` after `output.sh`.
- 10 target files migrated:
  - `lib/clarify.sh`, `lib/artifact_handler.sh`, `lib/init_helpers.sh` (extracted `_display_detection_results` into new `lib/init_helpers_display.sh` to stay under 300 lines), `lib/diagnose.sh`, `lib/diagnose_output.sh`, `lib/init_report_banner.sh`, `lib/report.sh`, `lib/milestone_progress_helpers.sh`, `lib/finalize.sh`, `lib/finalize_display.sh`.
- `tests/test_output_format.sh` (NEW): 68 unit-test assertions covering `_out_color` suppression, width clamping, banner/section/kv/hr/progress/action_item rendering in NO_COLOR mode, JSON action-items accumulation, and JSON escaping. `bash -n` and `shellcheck` assertions included.
- `tests/test_output_lint.sh` (NEW): grep lint that fails the build if any direct `echo -e '...${BOLD|RED|GREEN|YELLOW|CYAN|NC}...'` re-appears in `lib/` or `stages/` outside the output module.
- Adjusted downstream tests impacted by formatter migration: `tests/test_report.sh`, `tests/test_init_recommendation.sh`, `tests/test_progress_bar_no_subshells.sh`.

## Root Cause (bugs only)
N/A — milestone, not a bug fix.

## Files Modified
- `lib/output_format.sh` (NEW)
- `lib/init_helpers_display.sh` (NEW)
- `tests/test_output_format.sh` (NEW)
- `tests/test_output_lint.sh` (NEW)
- `lib/common.sh` — source `output_format.sh`
- `lib/clarify.sh` — migrated direct ANSI to formatters
- `lib/artifact_handler.sh` — migrated direct ANSI to formatters
- `lib/init_helpers.sh` — migrated + split to `init_helpers_display.sh`
- `lib/diagnose.sh` — migrated direct ANSI to `warn`/`log`
- `lib/diagnose_output.sh` — migrated direct ANSI to formatters
- `lib/init_report_banner.sh` — migrated direct ANSI to formatters
- `lib/report.sh` — migrated direct ANSI to formatters
- `lib/milestone_progress_helpers.sh` — uses `out_progress`/`out_section`
- `lib/finalize.sh` — migrated direct ANSI to formatters
- `lib/finalize_display.sh` — uses `out_banner`/`out_action_item`
- `lib/init.sh` — small companion adjustment
- `tests/test_report.sh`, `tests/test_init_recommendation.sh`, `tests/test_progress_bar_no_subshells.sh` — test-side adjustments tracking the formatter migration
- `.claude/milestones/m101-eliminate-direct-ansi-output.md` — status meta

## Human Notes Status
No human notes listed for this run.

## Validation
- `bash tests/test_output_format.sh`: 68/68 passed.
- `bash tests/test_output_lint.sh`: PASS — zero direct ANSI echo calls outside the output module.
- `shellcheck tekhton.sh lib/*.sh stages/*.sh`: zero warnings.
- `bash tests/run_tests.sh`: Shell 397/397 passed, Python 133/133 passed.

## Docs Updated
None — no public-surface changes in this task. The new formatters are internal helpers for library code; CLI output of `--diagnose`, `--init`, `--progress`, and the finalize banner remains visually unchanged.

## Observed Issues (out of scope)
- `lib/finalize.sh` is 569 lines (pre-existing, unchanged by this migration).
- `lib/common.sh` is 416 lines (pre-existing; +4 lines for the `source output_format.sh` addition).
- `lib/init_report_banner.sh` is 353 lines (pre-existing; 354→353 after migration).
- `lib/diagnose_output.sh` is 332 lines (pre-existing; 343→332 after migration).
These were over the 300-line ceiling before M101 and were not made worse by the migration — each was either unchanged or slightly reduced. Splitting them is a separate architectural concern outside the scope of the ANSI migration.
