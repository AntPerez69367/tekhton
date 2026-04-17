# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-17 | "M95"] `_route_audit_verdict()` (`lib/test_audit_verdict.sh:40`) has no `*)` wildcard in the case statement — an unexpected verdict (not PASS/CONCERNS/NEEDS_WORK) silently returns 0. Callers sanitize via `_parse_audit_verdict`, so it cannot fire today, but a catch-all `*) warn "Unknown verdict: ${verdict}"; return 0 ;;` would make the fail-safe explicit.
- [ ] [2026-04-17 | "M95"] Milestone acceptance criteria (`m95-test-audit-sh-file-split.md:131`) says "All four extracted functions" but the implementation correctly extracted seven (2+2+3). The criterion was written before the helpers extraction was decided. Minor doc gap — no functional issue.
- [ ] [2026-04-16 | "M92"] `orchestrate_helpers.sh:39` still uses `get_milestone_count "CLAUDE.md"` (hardcoded string). This was out of scope — the architect plan only targeted the two `find_next_milestone` call sites. Flagged for awareness; consistent with the named-fix-only scope.
- [ ] [2026-04-16 | "M91"] `lib/orchestrate_helpers.sh:221–235` — The `_escalate_turn_budget` awk-unavailable fallback branch (`else` block) itself contains an `awk` pipeline call for factor parsing. If `awk` truly isn't available, the `|| echo "150"` guard fires (hardcoding 1.5 regardless of `REWORK_TURN_ESCALATION_FACTOR`), so the code is safe — but the branch is logically self-contradictory. Additionally, the awk factor-to-integer expression `($2 "0") / 10**(length($2)-2)` is mathematically incorrect for single-decimal factors (produces 600 for "1.5" instead of 150), meaning on the rare system without awk, escalation would jump straight to cap on the first hit. This code path is effectively dead on any real Unix system, but could be simplified to pure shell arithmetic.
- [ ] [2026-04-16 | "M91"] `stages/review.sh:266` — The senior coder rework invocation uses `"$CODER_MAX_TURNS"` (base, no escalation), while both jr coder rework sites at lines 283 and 300 correctly use `"${EFFECTIVE_JR_CODER_MAX_TURNS:-$JR_CODER_MAX_TURNS}"`. This is consistent with the stated CODER_SUMMARY scope and is unlikely to matter in practice (review's rework coder hitting max_turns doesn't surface to the outer orchestrator as a `split` recovery case), but the inconsistency could confuse future maintainers and leaves a gap if the recovery classification ever changes.

## Resolved
