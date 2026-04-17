# Coder Summary

## Status: COMPLETE

## What Was Implemented

Milestone 94 — Failure Recovery CLI Guidance & `--diagnose` Overhaul.

**Tier 1 — Inline recovery block.**
`_print_recovery_block()` renders a WHAT HAPPENED / WHAT TO DO NEXT block
with a runnable `tekhton` resume command at every terminal exit path. It is
invoked from `_save_orchestration_state` after `write_pipeline_state`, so it
fires for every orchestration failure. Outcomes supported: `max_attempts`,
`timeout`, `agent_cap`, `pre_existing_failure`, and a fallback that echoes
the provided detail string. Colors guarded with `${BOLD:-}` / `${NC:-}` so
the block renders in test contexts.

**Tier 2 — `--diagnose` overhaul.**
Added `_rule_max_turns` — fires when `LAST_FAILURE_CONTEXT.json` has
`AGENT_SCOPE/max_turns`, `PIPELINE_STATE.md` Exit Reason contains
`complete_loop_max_attempts`, or Notes contains `max_turns`. Registered
before `_rule_review_loop` (more specific). All remaining rule suggestions
now include `_DIAG_PIPELINE_TASK` in their runnable commands (with
`${TASK:-<task not recorded>}` fallback). `_read_diagnostic_context` now
reads `LAST_FAILURE_CONTEXT.json` eagerly and extracts the `classification`
field — `RUN_SUMMARY.json` is enrichment only.

## Root Cause (bugs only)

N/A — new feature (M94).

## Files Modified

- `lib/orchestrate_recovery.sh` — Added `_print_recovery_block()` helper
  (placed here rather than orchestrate_helpers.sh to stay under the 300-line
  ceiling; orchestrate_recovery.sh is sourced first so the symbol is in scope).
- `lib/orchestrate_helpers.sh` — Call `_print_recovery_block` at the end of
  `_save_orchestration_state`.
- `lib/diagnose_rules.sh` — Added `_rule_max_turns`; updated all primary-rule
  DIAG_SUGGESTIONS to include runnable `tekhton` commands with
  `_DIAG_PIPELINE_TASK` substitution; removed 7 secondary rules that were
  extracted into `diagnose_rules_extra.sh`; sources the new sibling file;
  `DIAGNOSE_RULES` array grew from 13 to 14 entries with `_rule_max_turns`
  at index 1.
- `lib/diagnose_rules_extra.sh` **(NEW)** — Holds the 7 secondary rules
  (`_rule_stuck_loop`, `_rule_turn_exhaustion`, `_rule_split_depth`,
  `_rule_transient_error`, `_rule_test_audit_failure`, `_rule_migration_crash`,
  `_rule_version_mismatch`) with task-substituted runnable commands. Split
  out to keep `diagnose_rules.sh` under 300 lines.
- `lib/diagnose.sh` — `_read_diagnostic_context` now reads
  `LAST_FAILURE_CONTEXT.json` before `RUN_SUMMARY.json`, extracts
  `classification` into `_DIAG_LAST_CLASSIFICATION`, and captures
  `## Exit Reason` into `_DIAG_EXIT_REASON`.
- `tests/test_diagnose.sh` — Updated rule-count assertions (13 → 14),
  repositioned the priority checks, added Test Suite 2b for `_rule_max_turns`
  (fires from failure_ctx, Notes, and Exit Reason; no-match on unrelated
  fixtures); widened `_reset_fixture` to clear the new state vars.
- `tests/test_recovery_block.sh` **(NEW)** — Tests the recovery block's
  format and runnable-command content across `max_attempts`, `timeout`,
  `pre_existing_failure`, and fallback outcomes.

## Human Notes Status

No human notes in scope for this task.
