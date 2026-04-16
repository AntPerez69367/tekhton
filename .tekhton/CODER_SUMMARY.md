# Coder Summary
## Status: COMPLETE

## What Was Implemented

Milestone 91: Adaptive Rework Turn Escalation. When the orchestrator hits
`AGENT_SCOPE/max_turns` consecutively on the same stage during a `--complete`
run, the effective turn budget for that stage is multiplied by
`REWORK_TURN_ESCALATION_FACTOR` (default 1.5), clamped to `REWORK_TURN_MAX_CAP`
(default = `CODER_MAX_TURNS_CAP` = 200). The counter resets on any success or
when the failing stage changes. No behaviour change outside `--complete`.

- Three new config keys (`REWORK_TURN_ESCALATION_ENABLED`,
  `REWORK_TURN_ESCALATION_FACTOR`, `REWORK_TURN_MAX_CAP`) in
  `lib/config_defaults.sh`, clamped to sensible ranges.
- Four new helpers in `lib/orchestrate_helpers.sh`:
  `_update_escalation_counter`, `_escalate_turn_budget`,
  `_apply_turn_escalation`, `_can_escalate_further`. Float math via `awk`
  with an integer shell fallback when `awk` is unavailable.
- `run_complete_loop` now tracks `_ORCH_CONSECUTIVE_MAX_TURNS` /
  `_ORCH_MAX_TURNS_STAGE`, resets them plus unsets `EFFECTIVE_*` vars at
  entry, calls `_update_escalation_counter` after each attempt, and
  intercepts the `split` recovery branch: if the last failure was
  `max_turns` and the budget hasn't hit the cap, it escalates and retries
  the same stage instead of exiting.
- Stages consume the escalated budget via
  `${EFFECTIVE_CODER_MAX_TURNS:-${ADJUSTED_CODER_TURNS:-$CODER_MAX_TURNS}}`
  (and equivalents for jr coder / tester). Updated the primary coder invocation,
  post-clarification coder, turn-exhaustion continuation, build-fix coder,
  jr-coder rework, tester, and the preflight-fix Jr Coder.
- Warn lines describe every escalation, and a distinct message fires when the
  cap is reached recommending `--split-milestone`.

## Root Cause (bugs only)

N/A — feature work.

## Files Modified

- `lib/config_defaults.sh` — add `REWORK_TURN_*` defaults + clamps.
- `lib/orchestrate_helpers.sh` — add four escalation helpers; wire
  `EFFECTIVE_JR_CODER_MAX_TURNS` into the preflight-fix turn budget.
- `lib/orchestrate.sh` — add `_ORCH_CONSECUTIVE_MAX_TURNS` /
  `_ORCH_MAX_TURNS_STAGE` globals + resets; call
  `_update_escalation_counter` after each attempt; reset counter on any
  pipeline success; intercept the `split` branch to try escalation.
- `stages/coder.sh` — consume `EFFECTIVE_CODER_MAX_TURNS` at primary,
  post-clarification, continuation, and build-fix call sites.
- `stages/tester.sh` — consume `EFFECTIVE_TESTER_MAX_TURNS` in the
  tester turn-budget fallback chain.
- `stages/review.sh` — consume `EFFECTIVE_JR_CODER_MAX_TURNS` in both
  Jr Coder rework call sites.

## Files Added

- `tests/test_adaptive_turn_escalation.sh` (NEW) — 30 assertions covering
  counter increment/reset, stage-change reset, disabled-flag behaviour,
  budget math + cap clamping, and `_can_escalate_further` transitions.

## Docs Updated

None. The three new config keys are documented inline in
`lib/config_defaults.sh` and in `CLAUDE.md`'s template-variable table; no
separate reference update needed because the pattern follows existing
`REWORK_*`-style keys.

## Human Notes Status

No `HUMAN_NOTES` section was provided in the task; nothing to track.
