# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-16 | "M91"] `lib/orchestrate_helpers.sh:221–235` — The `_escalate_turn_budget` awk-unavailable fallback branch (`else` block) itself contains an `awk` pipeline call for factor parsing. If `awk` truly isn't available, the `|| echo "150"` guard fires (hardcoding 1.5 regardless of `REWORK_TURN_ESCALATION_FACTOR`), so the code is safe — but the branch is logically self-contradictory. Additionally, the awk factor-to-integer expression `($2 "0") / 10**(length($2)-2)` is mathematically incorrect for single-decimal factors (produces 600 for "1.5" instead of 150), meaning on the rare system without awk, escalation would jump straight to cap on the first hit. This code path is effectively dead on any real Unix system, but could be simplified to pure shell arithmetic.
- [ ] [2026-04-16 | "M91"] `stages/review.sh:266` — The senior coder rework invocation uses `"$CODER_MAX_TURNS"` (base, no escalation), while both jr coder rework sites at lines 283 and 300 correctly use `"${EFFECTIVE_JR_CODER_MAX_TURNS:-$JR_CODER_MAX_TURNS}"`. This is consistent with the stated CODER_SUMMARY scope and is unlikely to matter in practice (review's rework coder hitting max_turns doesn't surface to the outer orchestrator as a `split` recovery case), but the inconsistency could confuse future maintainers and leaves a gap if the recovery classification ever changes.
- [x] [2026-04-16 | "M91"] `lib/orchestrate_helpers.sh` is 321 lines — 21 over the 300-line soft ceiling, pushed there by the new escalation helpers (~90 lines). The `_try_preflight_fix` helper (lines 78–174) is the largest candidate for extraction into a dedicated file on the next cleanup pass.
- [ ] [2026-04-16 | "M89"] The three new config keys (`TEST_AUDIT_ROLLING_ENABLED`, `TEST_AUDIT_ROLLING_SAMPLE_K`, `TEST_AUDIT_HISTORY_MAX_RECORDS`) are not documented in the Template Variables table in `CLAUDE.md`. Other `TEST_AUDIT_*` keys are also absent from that table, so this continues an existing gap rather than introducing a new regression. Worth a future pass to add all `TEST_AUDIT_*` keys.

## Resolved
