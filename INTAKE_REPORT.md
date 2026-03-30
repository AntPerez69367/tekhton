## Verdict
TWEAKED

## Confidence
62

## Reasoning
- The bug is well-described with concrete, reproducible symptoms (specific wrong values, directionally-incorrect update behavior)
- The business impact is clearly stated
- However, there are no explicit acceptance criteria — only symptoms are listed
- No files to modify are identified, which is fine for a bug report but leaves the developer to locate the calculation code
- No UI testability criterion is listed for what is clearly a UI-facing fix
- The root cause is not stated (unit mismatch? wrong aggregation formula? incorrect data field?), but the symptoms are specific enough that a developer can diagnose and fix

## Tweaked Content

[BUG] Watchtower Trends page: Average stage times are incorrect. Tester shows 3:38 avg despite no run under 5 min; an 11-min run decreased the average to 3:21 instead of increasing it. The average run time shows as 8m50s when in actual fact most runs are well over 20 minutes, some reaching over an hour. This is critical for users to have an accurate expectation of how long runs will take and to see the impact of their optimizations.

**Acceptance Criteria:**

- [PM: Added from symptoms] Average stage durations displayed on the Trends page are mathematically correct: the displayed value equals the arithmetic mean of all included run durations for that stage
- [PM: Added from symptoms] Adding a run whose duration exceeds the current average increases the displayed average; adding a run shorter than the current average decreases it (directional correctness)
- [PM: Added from symptoms] The overall average run time reflects actual total run durations — runs known to exceed 20 minutes must not be represented as sub-10-minute in the average
- [PM: Added — UI testability] The Trends page loads without console errors after the fix, and all average time values render in a human-readable format consistent with the rest of the UI (e.g., `mm:ss` or `Xm Ys`)
- [PM: Added] If stage timing data comes from `RUN_SUMMARY.json` or a similar artifact, verify the correct field is being read and that unit conversions (seconds → minutes, milliseconds → seconds, etc.) are applied consistently
