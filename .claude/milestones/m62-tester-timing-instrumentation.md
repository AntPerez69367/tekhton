# Milestone 62: Tester Timing Instrumentation
<!-- milestone-meta
id: "62"
status: "pending"
-->

## Overview

The tester stage averages 19 minutes — longer than the coder (17 min) — but all
of that time is reported as a single `tester_agent` phase. There is no visibility
into how time splits between test writing, test execution, and failure debugging.
Without this breakdown, optimization efforts are guesswork.

This milestone adds sub-phase timing to the tester stage by parsing agent tool-use
logs for `TEST_CMD` invocations, and reports the split in TIMING_REPORT.md and
RUN_SUMMARY.json.

Depends on M56 for stable pipeline baseline.

## Scope

### 1. Test Command Execution Extraction

**File:** `lib/timing.sh`

After the tester agent completes, parse the agent's JSON output log for Bash
tool invocations that match `TEST_CMD` patterns. For each match, extract:
- Timestamp (from tool call sequence)
- Duration (from tool result timing if available, or infer from sequence gaps)
- Whether it was a per-file run or full-suite run (heuristic: contains a
  specific test file path vs. bare `TEST_CMD`)

Aggregate into:
- `tester_test_execution_s` — total seconds spent in TEST_CMD invocations
- `tester_test_execution_count` — number of TEST_CMD invocations
- `tester_writing_s` — remainder (total agent time minus test execution time)

### 2. TIMING_REPORT.md Enhancement

**File:** `lib/timing.sh`

When tester sub-phase data is available, expand the tester line:
```markdown
| Tester (agent) | 19m 12s | 45% |
|   ↳ Test writing | 8m 30s | 20% |
|   ↳ Test execution (×7) | 10m 42s | 25% |
```

### 3. RUN_SUMMARY.json Enhancement

**File:** `lib/finalize_summary.sh`

Add sub-fields to the tester stage entry:
```json
{
  "tester": {
    "turns": 45,
    "duration_s": 1152,
    "budget": 100,
    "test_execution_s": 642,
    "test_execution_count": 7,
    "test_writing_s": 510
  }
}
```

### 4. Coder Build Gate Timing Parity

**File:** `lib/timing.sh`

Apply the same extraction logic to the coder's build gate — report how much of
the coder stage was code writing vs. build command execution. This provides an
apples-to-apples comparison.

## Migration Impact

No new config keys. Timing data is purely additive to existing reports.

## Acceptance Criteria

- TIMING_REPORT.md shows tester sub-phase breakdown (writing vs. execution)
- RUN_SUMMARY.json includes `test_execution_s` and `test_writing_s` for tester
- Build gate execution time shown separately in coder breakdown
- Sub-phase extraction handles missing/unparseable logs gracefully (falls back
  to single-phase reporting)
- All existing tests pass
- Timing overhead < 500ms (log parsing is post-hoc, not inline)

Tests:
- Parse logic extracts TEST_CMD invocations from sample agent output JSON
- Per-file vs. full-suite heuristic correctly classifies test runs
- Missing agent logs produce graceful fallback (no sub-phase data, no crash)
- Timing report markdown renders correctly with sub-phases

Watch For:
- Agent output format may vary between Claude CLI versions. Parse defensively.
- The `--output-format json` flag gives structured output, but tool-use details
  may be nested differently. Test against real agent output samples.
- Sub-phase percentages should sum to the parent phase, not to total run time.

Seeds Forward:
- Writing vs. execution split directly informs whether to optimize test startup
  time or test authoring prompts
- Data feeds into adaptive turn calibration for tester-specific budgeting
