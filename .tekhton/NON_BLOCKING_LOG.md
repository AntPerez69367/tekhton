# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [x] [2026-04-21 | "[BUG] TUI Stage Timings panel has two related issues: (1) while a stage is active, elapsed time is shown in minutes+seconds (e.g. "1m 23s"), but once the stage completes it reverts to showing only seconds (e.g. "83s"); (2) the Review and Tester stages reset to 0s on completion regardless of actual elapsed time — their final recorded duration is always ~0s instead of the real value. They also show 0/0 turns regardless of how many they actually used."] `tests/test_metrics_total_time_computation.sh:143` still declares `[reviewer]=50` instead of `[review]=50`. Carried from previous review; the test checks JSON validity only (not the sum), so it doesn't fail, but the stale key exercises dead code.
- [x] [2026-04-21 | "[BUG] TUI Stage Timings panel has two related issues: (1) while a stage is active, elapsed time is shown in minutes+seconds (e.g. "1m 23s"), but once the stage completes it reverts to showing only seconds (e.g. "83s"); (2) the Review and Tester stages reset to 0s on completion regardless of actual elapsed time — their final recorded duration is always ~0s instead of the real value. They also show 0/0 turns regardless of how many they actually used."] `lib/config_defaults.sh` turn-limit increases (CODER_MIN_TURNS 40→60, REVIEWER_MIN_TURNS 15→20, REVIEWER_MAX_TURNS_CAP 50→60, TESTER_MIN_TURNS 20→30, TESTER_MAX_TURNS_CAP 100→120) remain unexplained in CODER_SUMMARY and are out of scope for this bug fix. Carried from previous review.

## Resolved
