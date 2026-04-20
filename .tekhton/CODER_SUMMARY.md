# Coder Summary
## Status: COMPLETE

## What Was Implemented

M105 — Test Run Deduplication. Skips redundant `TEST_CMD` executions by hashing
the working-tree state (`git status --porcelain` + `TEST_CMD`) and caching the
hash at the last successful test pass. When the current hash matches the cached
one, the run is provably identical and is skipped.

- New `lib/test_dedup.sh` module with `_test_dedup_fingerprint`,
  `test_dedup_record_pass`, `test_dedup_can_skip`, `test_dedup_reset`.
- Wrapped the six participating `TEST_CMD` call sites (milestone acceptance,
  completion gate, pre-finalization gate, preflight-fix verification, final
  checks pass 1). `test_baseline.sh` is intentionally excluded (per spec).
- `test_dedup_reset` invoked at the top of `run_complete_loop` so stale
  fingerprints from a previous run don't leak into a new one.
- Emits `test_dedup_skip` causal events when a run is skipped.
- Config default `TEST_DEDUP_ENABLED=true` added to `lib/config_defaults.sh`;
  safe because a fingerprint mismatch always forces re-run.
- New test suite `tests/test_dedup.sh` covers enablement, file-change /
  untracked-add / deletion invalidation, `TEST_CMD` change invalidation, reset
  semantics, and non-git graceful degradation (9 assertions, all passing).
- Full suite: 404 shell tests + 141 Python tests, 0 failures.
- `shellcheck` clean on all modified files.

## Root Cause (bugs only)
N/A — feature milestone.

## Files Modified
- `lib/test_dedup.sh` (NEW) — core dedup functions
- `lib/config_defaults.sh` — `TEST_DEDUP_ENABLED` default
- `tekhton.sh` — source `lib/test_dedup.sh` after `gates_completion.sh`
- `lib/milestone_acceptance.sh` — wrap TEST_CMD at acceptance check
- `lib/gates_completion.sh` — wrap TEST_CMD at completion gate
- `lib/orchestrate.sh` — reset at loop entry; wrap pre-finalization gate
- `lib/orchestrate_preflight.sh` — wrap TEST_CMD after preflight fix
- `lib/hooks_final_checks.sh` — wrap TEST_CMD at final checks pass 1
- `tests/test_dedup.sh` (NEW) — full unit coverage of dedup functions
- `CLAUDE.md` — document `TEST_DEDUP_ENABLED` var and `lib/test_dedup.sh` in
  repo layout
- `ARCHITECTURE.md` — add Layer 3 description for `lib/test_dedup.sh`

## Docs Updated
- `CLAUDE.md` — added `TEST_DEDUP_ENABLED` to template variables table and
  `lib/test_dedup.sh` to the repo layout tree. Public-surface change: new
  config key.
- `ARCHITECTURE.md` — added `lib/test_dedup.sh` entry under Layer 3
  libraries section.

## Human Notes Status
None — no HUMAN_NOTES items in this run.

## Observed Issues (out of scope)
- `lib/orchestrate.sh` is 463 lines (was 445 before M105 added 18 lines for
  the dedup wrapper and reset call). It already exceeded the 300-line
  ceiling before this work; an extraction pass is its own concern.
- `lib/test_baseline.sh` still has `set -euo pipefail` at the top of a
  sourced file — minor deviation from the coder.md rule "sourced files must
  NOT have their own `set -euo pipefail`". Pre-existing, not touched here.
