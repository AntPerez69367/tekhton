# Drift Log

## Metadata
- Last audit: 2026-04-19
- Runs since audit: 1

## Unresolved Observations
- [2026-04-19 | "M101"] `lib/init_helpers_display.sh` was extracted from `init_helpers.sh` to keep `init_helpers.sh` under the 300-line ceiling, but the new file itself uses `echo -e` with aliased ANSI locals — a pattern that the lint test was designed to eliminate. The extraction preserved the old style rather than converting it, creating a latent gap in lint coverage.
- [2026-04-19 | "M101"] `test_output_lint.sh` checks `lib/` and `stages/` but excludes only `lib/common.sh`, `lib/output.sh`, `lib/output_format.sh`. If `lib/output_format.sh` itself ever exceeds 300 lines and is split, the exclusion list will need updating — a fragile coupling between file layout and lint configuration.
- [2026-04-19 | "architect audit"] **OBS-1 and OBS-2** (both entries from the 2026-04-18 audit): Both were already self-annotated "Verified stale. No action required." by the prior architect pass. Confirmed by direct file inspection:
- [2026-04-19 | "architect audit"] `lib/common.sh` line 110 is a blank-line comment separator; no formatting issue.
- [2026-04-19 | "architect audit"] `lib/tui_helpers.sh:_tui_json_build_status` emits no `"stage"` field; no duplication with `"stage_label"`. No code changes are warranted. The only required action is closing these observations in the drift log.

## Resolved
- [RESOLVED 2026-04-19] **OBS-1: `lib/common.sh:110` — "No blank line between `error()` close and `mode_info()` comment block"** Verified stale. Current `lib/common.sh` line 110 is a blank line separating `error()` (closes at line 109) from `mode_info()` (opens at line 111). The `mode_info()` function also has no comment block — it begins directly with `mode_info() {`. The stated condition does not exist in the codebase. No action required. **OBS-2: `lib/tui_helpers.sh:_tui_json_build_status` — `"stage"` field duplicates `"stage_label"`** Verified stale. Current `_tui_json_build_status` (lines 115–139) emits `"stage_num"`, `"stage_total"`, and `"stage_label"` but no `"stage"` field. The test fixture `_sample_status()` in `tools/tests/test_tui.py` (lines 27–56) likewise has no `"stage"` key. The duplication referenced in the observation does not exist. No action required.
