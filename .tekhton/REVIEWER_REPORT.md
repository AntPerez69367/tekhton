# Reviewer Report — M94: Failure Recovery CLI Guidance

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `_rule_max_turns` reads the Exit Reason section from the state file directly (its own `awk` call) even though `_read_diagnostic_context` already populates `_DIAG_EXIT_REASON` for that purpose. Minor duplication — not a bug, but `_DIAG_EXIT_REASON` could be used instead to keep rule reads consistent with the module contract.
- In `test_diagnose.sh` test 2b.6, `sed -i 's/## Notes/## Notes\nHit max_turns in coder/'` inserts via GNU sed newline syntax — correct for WSL/Linux but would silently fail on BSD sed. Low risk given the platform, but worth noting for portability.

## Coverage Gaps
- `test_recovery_block.sh` covers `max_attempts`, `timeout`, `pre_existing_failure`, and the fallback but does not test the `agent_cap` outcome. The case branch exists in `_print_recovery_block` (uses `MAX_AUTONOMOUS_AGENT_CALLS` in `what_happened`) and should be exercised.

## Drift Observations
- `tests/test_diagnose.sh` is 666 lines — well over the 300-line soft ceiling. This was pre-existing before M94 (M94 added ~50 lines for suite 2b). Worth tracking; the fixture/helper functions could eventually be extracted into a shared test helper.
- `_rule_turn_exhaustion` in `diagnose_rules_extra.sh` reads `AGENT_SCOPE/max_turns` from the pipeline state file and is now superseded by `_rule_max_turns` whenever `LAST_FAILURE_CONTEXT.json` is present (which is the normal post-M93 path). Kept for backward-compatibility per coder note, but it is effectively dead code for post-M93 runs. Worth a comment or eventual removal.
