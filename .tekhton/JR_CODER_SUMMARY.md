# Junior Coder Summary — 2026-04-21

## What Was Fixed

- **`tests/test_pipeline_order_policy.sh` line 109**: Updated assertion to expect `get_stage_array_key("review")` → `"review"` (was `"reviewer"`). Updated test label to reflect idempotent contract: `"review → review"`.

- **`tests/test_pipeline_order_policy.sh` line 115**: Updated assertion to expect `get_stage_array_key("test_write")` → `"tester-write"` (was `"tester_write"`). Updated test label accordingly: `"test_write → tester-write"`.

Both updates align with the complex-blocker fixes in `lib/pipeline_order_policy.sh` that change `get_stage_array_key` to return the new canonical keys (`review` instead of `reviewer`, `tester-write` instead of `tester_write`).

## Files Modified

- `tests/test_pipeline_order_policy.sh`
