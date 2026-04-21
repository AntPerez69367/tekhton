# Reviewer Report — 2026-04-21 (Cycle 2 re-review)

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `tests/test_metrics_total_time_computation.sh:143` still declares `[reviewer]=50` instead of `[review]=50`. Carried from previous review; the test checks JSON validity only (not the sum), so it doesn't fail, but the stale key exercises dead code.
- `lib/config_defaults.sh` turn-limit increases (CODER_MIN_TURNS 40→60, REVIEWER_MIN_TURNS 15→20, REVIEWER_MAX_TURNS_CAP 50→60, TESTER_MIN_TURNS 20→30, TESTER_MAX_TURNS_CAP 100→120) remain unexplained in CODER_SUMMARY and are out of scope for this bug fix. Carried from previous review.

## Coverage Gaps
- None

## Prior Blocker Disposition

**Complex blocker 1 — `get_stage_array_key` wrong keys**: FIXED.
`lib/pipeline_order_policy.sh:46-53` now returns `"review"` for the `review)` arm and `"tester-write"` for the `test_write)` arm. The TUI dispatch at `tekhton.sh:2533` calls `get_stage_array_key("$_stage_name")` and correctly indexes `_STAGE_DURATION`, `_STAGE_TURNS`, and `_STAGE_BUDGET` using those keys. The associated `_STAGE_*[review]` writes at lines 2452-2465 and `_STAGE_*[tester-write]` writes at lines 2484-2493 are consistent with the resolved keys. Verified: the function's idempotent invariant is now correct — `get_stage_array_key("review")` → `"review"`.

**Complex blocker 2 — `lib/metrics.sh:97` reads stale `[reviewer]` key**: FIXED.
Line 97 now reads `reviewer_duration_s="${_STAGE_DURATION[review]:-0}"`. Confirmed in the file; no regression against the summation loop at lines 121-124 (which iterates all keys).

**Complex blocker 3 — Bug #1 format inconsistency (active "1m23s" vs completed "90s")**: FIXED.
`tools/tui_render_timings.py` introduces `_normalize_time()` which intercepts `"<int>s"` tokens (the form bash sends via `tui_stage_end`) and routes them through `_fmt_duration`. Both the live row (`_fmt_duration(live_elapsed)`) and the completed row (`_normalize_time` → `_fmt_duration`) now use the same formatter — consistent output. Edge cases verified: `"0s"` → `"0s"`, already-formatted strings (contain non-digit chars before `s`) pass through unchanged, empty string short-circuits immediately.

**Simple blocker — `test_pipeline_order_policy.sh` stale assertions**: FIXED.
Line 109 now asserts `"review"` → `"review"` and line 115 now asserts `"test_write"` → `"tester-write"`, matching the corrected `get_stage_array_key` contract.

**Non-blocking note — stale inline comment at `tekhton.sh:2526`**: FIXED.
Comment now reads `_STAGE_*[review|tester|tester-write]`, correctly describing the migrated keys.

## Drift Observations
- `tests/test_metrics_total_time_computation.sh:143` uses `[reviewer]=50` (stale key). The test exercises `record_run_metrics` with an array that no production code path would produce after the M110 migration. It passes only because the assertion checks JSON schema, not the computed value. The stale fixture quietly tests nothing meaningful about the `reviewer_duration_s` field.
