# Reviewer Report — M91: Adaptive Rework Turn Escalation

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `lib/orchestrate_helpers.sh:221–235` — The `_escalate_turn_budget` awk-unavailable fallback branch (`else` block) itself contains an `awk` pipeline call for factor parsing. If `awk` truly isn't available, the `|| echo "150"` guard fires (hardcoding 1.5 regardless of `REWORK_TURN_ESCALATION_FACTOR`), so the code is safe — but the branch is logically self-contradictory. Additionally, the awk factor-to-integer expression `($2 "0") / 10**(length($2)-2)` is mathematically incorrect for single-decimal factors (produces 600 for "1.5" instead of 150), meaning on the rare system without awk, escalation would jump straight to cap on the first hit. This code path is effectively dead on any real Unix system, but could be simplified to pure shell arithmetic.
- `stages/review.sh:266` — The senior coder rework invocation uses `"$CODER_MAX_TURNS"` (base, no escalation), while both jr coder rework sites at lines 283 and 300 correctly use `"${EFFECTIVE_JR_CODER_MAX_TURNS:-$JR_CODER_MAX_TURNS}"`. This is consistent with the stated CODER_SUMMARY scope and is unlikely to matter in practice (review's rework coder hitting max_turns doesn't surface to the outer orchestrator as a `split` recovery case), but the inconsistency could confuse future maintainers and leaves a gap if the recovery classification ever changes.
- `lib/orchestrate_helpers.sh` is 321 lines — 21 over the 300-line soft ceiling, pushed there by the new escalation helpers (~90 lines). The `_try_preflight_fix` helper (lines 78–174) is the largest candidate for extraction into a dedicated file on the next cleanup pass.

## Coverage Gaps
- No integration test covers the full outer-loop escalation trigger path (orchestrate.sh `split` branch → `_apply_turn_escalation` → retry with escalated budget). The unit tests (`test_adaptive_turn_escalation.sh`) cover all four helpers in isolation, including cap clamping and disabled-flag behavior, which is the right depth for these primitives. A future integration test for the orchestration loop would increase confidence in the `_ORCH_CONSECUTIVE_MAX_TURNS` wiring, but this is not a tester concern.

## ACP Verdicts
None — no Architecture Change Proposals in CODER_SUMMARY.md.

## Drift Observations
- `lib/orchestrate_helpers.sh` now bundles three semantically distinct concerns: auto-advance chain, preflight-fix retry, and escalation counter logic. As the file continues to grow, consider extracting `_try_preflight_fix` into `orchestrate_preflight.sh` to restore the 300-line ceiling and keep escalation helpers easy to locate.
