# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-17 | "Fix the failing test from the test suite"] Note 2 (m95 doc: "four" → "seven" extracted functions) remains unaddressed due to permission gate on `.claude/milestones/*.md`; requires a manual one-line edit — no functional impact.
- [ ] [2026-04-17 | "Fix the failing test from the test suite"] Three additional hardcoded `get_milestone_count "CLAUDE.md"` call sites remain at `tekhton.sh:2018`, `tekhton.sh:2031`, and `stages/coder.sh:34` — only the one explicitly called out in Note 3 was in scope, but these are candidates for a follow-up normalisation pass.

## Resolved
