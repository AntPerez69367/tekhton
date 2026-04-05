# Milestone 64: Tester Fix — Surgical Mode
<!-- milestone-meta
id: "64"
status: "pending"
-->

## Overview

When `TESTER_FIX_ENABLED=true` and the tester stage detects test failures, it
spawns a **complete recursive pipeline run** — coder, reviewer, tester, all
stages. For a single failing test, this can add 40+ minutes to the run. The
recursive approach was designed for cases where implementation bugs cause test
failures, but most tester-stage failures are simpler: wrong assertions, missing
imports, stale mocks, or constructor signature mismatches.

This milestone replaces the full-pipeline recursion with a lightweight surgical
fix agent that operates within the tester stage itself, similar to how the coder's
build-fix retry works within the coder stage.

Depends on M63 (Test Baseline Hygiene) so the fix agent has accurate baseline
data and doesn't waste effort on pre-existing failures.

## Scope

### 1. Inline Tester Fix Agent

**File:** `stages/tester.sh`

Replace the recursive `tekhton.sh` invocation with a scoped fix agent:
- When tests fail after tester completion, extract failing test output
- Spawn a fix agent with a focused prompt: "Fix these test failures"
- Use `TESTER_FIX_MAX_TURNS` budget (default: `CODER_MAX_TURNS / 3`)
- Agent receives: failing test output, the test files, the source files
- Agent does NOT receive full pipeline context (no architecture docs, no
  design docs, no drift logs)
- Max `TESTER_FIX_MAX_DEPTH` attempts (default: 1)

### 2. Tester Fix Prompt

**File:** `prompts/tester_fix.prompt.md` (new)

Focused prompt for the surgical fix agent:
- "You are fixing test failures. The tests below are failing."
- Include: test output (capped at `TESTER_FIX_OUTPUT_LIMIT` chars), test file
  paths, source file paths from CODER_SUMMARY.md
- Include: `TEST_BASELINE_SUMMARY` so agent knows which failures are pre-existing
- Include: Serena/repo map guidance (from M65) so agent uses LSP tools
- Explicit instruction: "Fix the TEST code, not the implementation. If the
  implementation is wrong, document in TESTER_REPORT.md Bugs Found section."

### 3. Baseline-Aware Fix Gating

**File:** `stages/tester.sh`

Before spawning the fix agent, compare failures against `TEST_BASELINE_SUMMARY`:
- If all failures match baseline → skip fix, log "all failures pre-existing"
- If mix of new + pre-existing → fix only new failures (filter test output)
- If no baseline available → fix all failures (conservative)

### 4. Remove Recursive Pipeline Spawn

**File:** `stages/tester.sh`

Remove the `TEKHTON_FIX_DEPTH` / recursive `tekhton.sh` invocation. Replace
entirely with the inline fix agent. The `TESTER_FIX_MAX_DEPTH` config key is
repurposed to mean "max inline fix attempts" rather than "max recursive pipeline
depth."

## Migration Impact

| Key | Default | Change |
|-----|---------|--------|
| `TESTER_FIX_ENABLED` | `false` | No change — still opt-in |
| `TESTER_FIX_MAX_DEPTH` | `1` | Now means inline fix attempts, not pipeline recursions |
| `TESTER_FIX_MAX_TURNS` | `CODER_MAX_TURNS / 3` | New key — turn budget per fix attempt |
| `TESTER_FIX_OUTPUT_LIMIT` | `4000` | No change |

## Acceptance Criteria

- Tester fix uses inline agent, NOT recursive pipeline spawn
- Fix agent receives focused context (test output + files only)
- Pre-existing failures are filtered out before fix attempt
- Fix agent has Serena/repo map access when available
- `TESTER_FIX_MAX_DEPTH=0` disables fix attempts
- Fix agent time is tracked as `tester_fix` sub-phase in timing report
- All existing tests pass
- Fix attempts are logged in causal event log

Tests:
- Fix agent spawns with correct scoped context (no architecture/design bloat)
- Pre-existing failure filtering skips fix when all failures are baseline
- Mixed failures correctly filter to only new failures
- `TESTER_FIX_ENABLED=false` skips fix entirely
- Turn budget respected (agent doesn't exceed `TESTER_FIX_MAX_TURNS`)

Watch For:
- The fix agent should NOT modify implementation code. If it does, the reviewer
  hasn't validated those changes. The prompt must be explicit about this boundary.
- Some test failures genuinely require implementation fixes (real bugs found by
  tests). The fix agent should document these in Bugs Found rather than attempting
  a fix it's not scoped for.
- The `TESTER_FIX_OUTPUT_LIMIT` cap must be sufficient to include the actual
  error messages, not just stack traces. Consider smart truncation (keep first
  and last N lines of each failure).

Seeds Forward:
- Surgical fix data feeds into run metrics for fix success rate tracking
- Pattern of scoped fix agents could be reused for review rework
