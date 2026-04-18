# Reviewer Report — M97 TUI Mode (Cycle 2 Re-review)

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `_tui_json_build_status` emits both `"stage"` and `"stage_label"` with identical values (both sourced from `$stage_label`). The Python renderer uses only `stage_label`; the `stage` key is dead weight. Not broken — carry forward for cleanup.

## Coverage Gaps
- No shell-level test for the active-path write cycle: `tui_update_stage` / `tui_update_agent` / `tui_finish_stage` active paths have no assertions beyond "no error returned". Tester can add active-path assertions for at least one update function.

## ACP Verdicts
(no ACP section in CODER_SUMMARY.md — omitted)

## Drift Observations
- `tui_helpers.sh:_tui_json_build_status` — the `"stage"` field (line 122) duplicates `"stage_label"` (line 125), both set to `$stage_label`. The test fixture in `tools/tests/test_tui.py` uses distinct values (`stage="coder"`, `stage_label="Coder"`), implying the schema intended them to differ. Worth resolving when the JSON schema is next touched.

---

## Prior Blocker Verification

**Blocker: `set -euo pipefail` missing from `lib/tui.sh` and `lib/tui_helpers.sh`**
- `lib/tui.sh` line 13: `set -euo pipefail` — FIXED ✓
- `lib/tui_helpers.sh` line 9: `set -euo pipefail` — FIXED ✓

No regressions introduced. The fix was two lines added to the correct positions (after the shebang/header, before any executable code).
