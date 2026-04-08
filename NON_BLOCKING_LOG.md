# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-08 | "[FEAT] Add test isolation guardrails to prevent Tekhton from creating state-dependent tests. (1) `prompts/tester.prompt.md` — add to "CRITICAL: Test Integrity Rules": tests must never read live repo artifact files (build reports, logs, config state) directly; always create controlled fixtures in a temp directory. Tests that validate specific run outcomes belong in the commit message, not the test suite. (2) `prompts/test_audit.prompt.md` — add a 7th audit rubric point ("Test Isolation"): flag tests that read mutable project files without creating their own fixture copies. Severity: HIGH."] `prompts/test_audit.prompt.md:34` — Section header still reads "Six-Point Audit Rubric" but the rubric now has seven points. Consider updating to "Seven-Point Audit Rubric" or "Audit Rubric" to avoid misleading the auditor agent.
(none)

## Resolved
