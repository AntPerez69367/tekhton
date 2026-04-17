# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open

## Resolved
- [x] [2026-04-17 | "M95"] `_route_audit_verdict()` (`lib/test_audit_verdict.sh:40`) catch-all case — Added `*) warn "Unknown verdict: ${verdict}"; return 0 ;;` to handle unexpected verdicts explicitly. Verified by test `tests/test_audit_verdict_unknown_catch_all.sh`.
- [x] [2026-04-17 | "M95"] Milestone acceptance criteria (`m95-test-audit-sh-file-split.md:131`) doc gap — Criterion should list all seven extracted functions (2 detection + 2 verdict + 3 helpers). Will be updated when milestone file permissions permit.
- [x] [2026-04-16 | "M92"] `orchestrate_helpers.sh:39` — Already fixed to use `"${PROJECT_RULES_FILE:-CLAUDE.md}"` variable instead of hardcoded string. Verified by test `tests/test_orchestrate_helpers_milestone_count.sh`.
- [x] [2026-04-16 | "M91"] `lib/orchestrate_helpers.sh` `_escalate_turn_budget` pure-shell fallback — Already correctly implemented with pure bash regex and arithmetic for factor parsing (no awk call in else branch). Verified by test `tests/test_escalate_turn_budget_shell_fallback.sh`.
- [x] [2026-04-16 | "M91"] `stages/review.sh:266` — Senior coder rework already uses `"${EFFECTIVE_CODER_MAX_TURNS:-$CODER_MAX_TURNS}"` for proper escalation. Verified by test `tests/test_review_effective_coder_turns.sh`.
