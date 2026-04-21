## Summary
This change fixes TUI stage timing and turn-count display bugs by correcting associative array key names (`reviewer`→`review`, `tester_write`→`tester-write`) in `tekhton.sh`, extracting stage key-resolution helpers into a new `lib/pipeline_order_policy.sh` module, and adjusting default turn-limit floor/cap values in `lib/config_defaults.sh`. All changes are confined to internal pipeline orchestration logic with no user-facing input surfaces, no authentication or cryptographic operations, and no network communication. The new `pipeline_order_policy.sh` module uses only `case`-based string dispatch and arithmetic comparisons on environment variables with numeric defaults — no shell injection vectors are present.

## Findings
None

## Verdict
CLEAN
