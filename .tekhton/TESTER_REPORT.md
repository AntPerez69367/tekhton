## Planned Tests
- [x] `tests/test_audit_verdict_unknown_catch_all.sh` — Test `_route_audit_verdict` handles unknown verdicts with catch-all case
- [x] `tests/test_orchestrate_helpers_milestone_count.sh` — Test `get_milestone_count` uses `PROJECT_RULES_FILE` variable
- [x] `tests/test_escalate_turn_budget_shell_fallback.sh` — Test pure-shell fallback in `_escalate_turn_budget` when awk unavailable
- [x] `tests/test_review_effective_coder_turns.sh` — Test senior coder rework uses `EFFECTIVE_CODER_MAX_TURNS` escalation

## Test Run Results
Passed: 4  Failed: 0

## Bugs Found
None

## Files Modified
- [x] `lib/orchestrate_helpers.sh` — Fixed `_escalate_turn_budget` to gracefully fall back when awk fails (line 123)
- [x] `tests/test_escalate_turn_budget_shell_fallback.sh` — Fixed fake awk shebang from `/usr/bin/env bash` to `/bin/sh`
