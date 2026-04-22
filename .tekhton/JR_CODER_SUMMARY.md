# JR Coder Summary — Architect Remediation Cleanup

## What Was Fixed

### SF-1: Documentation Updates for pipeline_order Files

Added `lib/pipeline_order.sh` and `lib/pipeline_order_policy.sh` entries to both project documentation files:

- **CLAUDE.md (Repository Layout)**: Added two lines in the `lib/` section (alphabetical order, near `notes_core.sh`)
  - `pipeline_order.sh` — Configurable pipeline stage ordering
  - `pipeline_order_policy.sh` — M110 extraction for metrics key resolution and stage plan helpers

- **ARCHITECTURE.md (Layer 3 Libraries)**: Added corresponding function listings after `clarify.sh`
  - `pipeline_order.sh` — Documents public functions: `validate_pipeline_order()`, `get_pipeline_order()`, `get_stage_count()`, `get_stage_display_label()`
  - `pipeline_order_policy.sh` — Documents sourced internal functions and notes that it's extracted from the parent module

### SF-2: Fixed Stale Test Fixture

**File**: `tests/test_metrics_total_time_computation.sh`

- **Line 143**: Changed fixture key from `[reviewer]=50` to `[review]=50` — the metrics.sh code reads `_STAGE_DURATION[review]` not `_STAGE_DURATION[reviewer]`
- **Lines 149-158**: Added assertion to verify the emitted JSON contains `"reviewer_duration_s":50`, ensuring the test validates the actual output value (not just JSON format validity)

This prevents the false positive where the test passed even though `reviewer_duration_s` was always 0 in the metrics output.

### NN-1: Normalize Function Guard Idiom

Replaced `command -v` with `declare -f` for shell function existence checks in three locations:

- **`stages/coder_prerun.sh:69`** — Dedup-skip branch in `_run_prerun_fix_agent()`
- **`stages/coder_prerun.sh:132`** — Dedup-skip branch in pre-run verification path
- **`stages/tester_fix.sh:164`** — Dedup-skip branch in `_tester_fix_attempt()`

All three instances guard calls to `emit_event()`. Changed from `if command -v emit_event &>/dev/null;` to `if declare -f emit_event &>/dev/null;` to match the codebase-wide convention used in adjacent code in the same files. No behavioral change — both forms evaluate identically at runtime.

## Files Modified

- `CLAUDE.md` — Repository layout table (2 lines added)
- `ARCHITECTURE.md` — Layer 3 library descriptions (2 entries added)
- `tests/test_metrics_total_time_computation.sh` — Test fixture + assertion (1 key fixed, 5 lines added)
- `stages/coder_prerun.sh` — Guard idiom (2 instances fixed)
- `stages/tester_fix.sh` — Guard idiom (1 instance fixed)

## Verification

- **Bash syntax**: ✓ All files pass `bash -n`
- **Shellcheck**: ✓ No new warnings introduced (pre-existing SC2034 and SC1091 in test file are acceptable)
