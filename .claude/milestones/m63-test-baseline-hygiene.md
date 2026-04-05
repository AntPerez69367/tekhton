# Milestone 63: Test Baseline Hygiene & Completion Gate Hardening
<!-- milestone-meta
id: "63"
status: "pending"
-->

## Overview

Tekhton is designed to leave the repo in a pristine state — all tests passing,
no build errors. However, the test baseline system has gaps that allow runs to
complete with failing tests or misclassify new failures as "pre-existing":

1. **Stale baselines on resume:** `capture_test_baseline()` skips re-capture if
   `TEST_BASELINE.json` exists for the current milestone, even across separate
   runs. A baseline from Run A persists into Run B.
2. **Completion gate doesn't run tests:** `run_completion_gate()` only checks
   whether `CODER_SUMMARY.md` says "COMPLETE" — it never executes `TEST_CMD`.
3. **Tester blind to baseline:** The tester prompt has no `TEST_BASELINE_SUMMARY`
   context, so it cannot distinguish pre-existing failures from new ones when
   deciding whether to trigger `TESTER_FIX_ENABLED` auto-fix.
4. **Stuck detection can auto-pass:** When `TEST_BASELINE_PASS_ON_STUCK=true`,
   identical failures across 2+ attempts are auto-passed, even if the failures
   are genuine regressions from the current run.

This milestone hardens the test integrity guarantees so Tekhton never silently
passes a run with failing tests.

Depends on M56 for stable pipeline baseline.

## Scope

### 1. Fresh Baseline Per Run

**File:** `lib/test_baseline.sh`

Change `_should_capture_test_baseline()` to always re-capture at the start of
each new run, not just when the file is missing. Use a run-scoped marker (e.g.,
`TEST_BASELINE.json` includes `run_id` field) so resume within the same run
still skips re-capture, but a new run always gets a fresh baseline.

### 2. Inject TEST_BASELINE_SUMMARY into Tester

**Files:** `stages/tester.sh`, `prompts/tester.prompt.md`

Add `TEST_BASELINE_SUMMARY` to the tester's context, mirroring how coder.sh
injects it. Add a conditional block to `tester.prompt.md`:

```markdown
{{IF:TEST_BASELINE_SUMMARY}}
## Pre-Change Test Baseline
{{TEST_BASELINE_SUMMARY}}
Do NOT treat pre-existing failures as regressions from your test work.
{{ENDIF:TEST_BASELINE_SUMMARY}}
```

Context cost: ~200 tokens. Negligible.

### 3. Completion Gate Test Enforcement

**File:** `lib/gates.sh` (or `lib/gates_completion.sh`)

Add an optional hard test gate to the completion check. When `TEST_CMD` is
configured, run it as the final gate:
- Exit code 0 → pass
- Exit code non-zero → fail the completion gate (trigger retry or exit)
- Compare against baseline to filter pre-existing failures

Add config key `COMPLETION_GATE_TEST_ENABLED` (default: `true`). This ensures
no run can report success without passing tests.

### 4. Tighten Stuck Detection

**File:** `lib/test_baseline.sh`

Change stuck detection to be informational only by default:
- `TEST_BASELINE_PASS_ON_STUCK` default changes from `false` to `false` (no
  change needed, but document clearly)
- When stuck IS detected, emit a causal log event with classification
  `stuck_test_detected` and include the test output diff
- Never auto-pass if baseline was clean (exit_code=0) — if baseline had no
  failures, all current failures are definitionally new

### 5. Baseline Cleanup

**File:** `lib/test_baseline.sh`

Add `cleanup_stale_baselines()` called during finalization. Remove
`TEST_BASELINE.json` files from prior runs that are no longer relevant.
Keep only the current run's baseline (if any) and the most recent completed
run's baseline for comparison.

## Migration Impact

| Key | Default | Notes |
|-----|---------|-------|
| `COMPLETION_GATE_TEST_ENABLED` | `true` | Set to `false` to restore prior behavior (no test enforcement at completion) |

Existing `TEST_BASELINE_ENABLED`, `TEST_BASELINE_PASS_ON_STUCK`, and
`TEST_BASELINE_STUCK_THRESHOLD` settings continue to work unchanged.

## Acceptance Criteria

- Fresh baseline captured at start of each new run (not reused across runs)
- Resume within the same run reuses baseline (no unnecessary re-capture)
- Tester prompt includes `TEST_BASELINE_SUMMARY` when available
- Completion gate runs `TEST_CMD` and fails on non-zero exit (minus baseline)
- Stuck detection never auto-passes when baseline was clean
- Stale baseline files cleaned up during finalization
- All existing tests pass
- No run can report SUCCESS with genuinely failing tests

Tests:
- New run re-captures baseline even when `TEST_BASELINE.json` exists
- Resume within same run skips re-capture
- Tester prompt renders baseline block when summary is non-empty
- Completion gate catches test failures that acceptance gate missed
- Stuck detection with clean baseline never auto-passes
- Stale baseline cleanup removes old files, keeps current

Watch For:
- The completion gate test run adds wall-clock time to every successful run.
  This is acceptable because it's the only way to guarantee test integrity.
  If `TEST_CMD` is slow, users can disable with `COMPLETION_GATE_TEST_ENABLED=false`.
- Baseline re-capture means running `TEST_CMD` once more at run start. For
  projects with slow test suites, this adds startup cost. The trade-off is
  correctness — a stale baseline is worse than a 30-second test run.
- Ensure the tester's `TESTER_FIX_ENABLED` flow checks baseline before
  spawning a recursive pipeline — don't recurse for pre-existing failures.

Seeds Forward:
- Clean baseline guarantees make stuck detection more trustworthy
- Completion gate data feeds into run memory for cross-run quality tracking
