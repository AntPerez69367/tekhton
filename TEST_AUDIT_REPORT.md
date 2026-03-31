## Test Audit Report

### Audit Summary
Tests audited: 1 file (tests/test_notes_triage.sh), 33 pass/fail assertions across 17 suites
Verdict: CONCERNS

### Findings

#### COVERAGE: triage_before_claim promotion path untested
- File: tests/test_notes_triage.sh:269
- Issue: Suite 10 only exercises the `fit` path. n01 is a BUG note that scores <= 1 (disposition=fit), so `triage_before_claim` trivially returns 0 without ever entering the promotion decision logic. The function's primary purpose — detecting an oversized note whose `_TRIAGE_EST_TURNS` exceeds `HUMAN_NOTES_PROMOTE_THRESHOLD` and routing to promote/skip/keep — is never exercised. The return-1 code path, the auto-promote branch (`lib/notes_triage.sh:414`), and the confirm-mode `p`/`s`/`k` dispatch (`lib/notes_triage.sh:422`) have zero test coverage.
- Severity: HIGH
- Action: Add a test that sets up a note whose heuristic score is >= 5 (to ensure disposition=oversized), manually sets `_TRIAGE_EST_TURNS` above the promotion threshold, stubs `run_intake_create`, and verifies that `triage_before_claim` returns 1. A second case with `HUMAN_NOTES_PROMOTE_MODE=auto` closes the auto-promote branch.

#### COVERAGE: Suite 7 cache invalidation asserts presence, not updated value
- File: tests/test_notes_triage.sh:205
- Issue: After modifying n04's text from "Fix button alignment" to "Redesign entire button system across all pages", the test asserts `[[ "$line" =~ triage: ]]`. Since `triage:fit` was already written to the note in Suite 6, this assertion passes even if the cache-invalidation code is broken and the old "fit" value is silently reused. The new heuristic result should be "oversized" ("redesign" +3, "entire" +2, "all" +2 = 7 → score >= 5), but that updated value is never verified.
- Severity: MEDIUM
- Action: Change the assertion to `[[ "$line" =~ triage:oversized ]]` to confirm that the re-triage produced the newly computed result, not merely that some triage field exists.

#### COVERAGE: Mid-range score (2–4) in triage_note untested end-to-end
- File: tests/test_notes_triage.sh (no direct test)
- Issue: `triage_note` in `lib/notes_triage.sh:146` has no else branch for scores 2–4; those cases leave `_TRIAGE_DISPOSITION` at the default "fit" and trigger `_triage_agent_escalation`. No test calls `triage_note` (as opposed to `_triage_heuristic_score` directly) with a mid-range input to verify that: (a) disposition defaults to "fit" when `run_agent` is unavailable, and (b) the fallback in `_triage_agent_escalation` fires without error. Suite 3 tests confidence via the scoring function only and never exercises the full `triage_note` → agent escalation → fallback chain.
- Severity: MEDIUM
- Action: Add a test that calls `triage_note` on a note whose text scores 2–4 (e.g., "Add dark mode toggle" with FEAT — "add support for" is absent here, plain "Add" is not a keyword, so score ≈ 0–1; pick a phrasing that reliably hits 2–4) with no `run_agent` defined. Assert `_TRIAGE_DISPOSITION == "fit"` and confirm triage metadata is persisted.

#### COVERAGE: Suite 4 does not isolate the length +1 bonus
- File: tests/test_notes_triage.sh:110
- Issue: Suite 4 asserts that the test string's character count is > 120, confirming a precondition, but never compares the score for a long vs. short version of the same neutral text. Because the long-text example also contains scope keywords ("integration", "authentication", "API"), the +1 length contribution is invisible against keyword scoring and is effectively untested.
- Severity: LOW
- Action: Add a comparison: call `_triage_heuristic_score` with a keyword-free string exactly <= 120 chars to get a baseline score, then pad the same string to > 120 chars and assert the second score equals baseline + 1.

#### COVERAGE: _triage_agent_escalation fallback branches unreachable in test suite
- File: tests/test_notes_triage.sh (no direct test)
- Issue: `render_prompt` is stubbed to return `""`. All test inputs are chosen to score either >= 5 or <= 1, so `_TRIAGE_CONFIDENCE` is always "high" and `_triage_agent_escalation` is never called. Both fallback branches in `lib/notes_triage.sh:185` (`run_agent` unavailable) and `lib/notes_triage.sh:233` (empty prompt template) are dead code within this suite.
- Severity: LOW
- Action: Addressed as a side effect of the medium finding above — a mid-range `triage_note` test would reach the `run_agent not available` fallback branch at `lib/notes_triage.sh:185`.
