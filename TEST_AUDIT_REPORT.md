## Test Audit Report

### Audit Summary
Tests audited: 1 file, 15 test assertions
Verdict: CONCERNS

### Findings

#### INTEGRITY: Test 12 assertion matches pre-existing content, not Section 7 specifically
- File: tests/test_prompt_isolation_guardrails.sh:113
- Issue: `assert_contains` checks for pattern `"Severity: HIGH"` to verify that Section 7 marks isolation violations as HIGH severity. This exact string appears at TWO locations in `prompts/test_audit.prompt.md`: (1) line 86 in Section 7 (`is Severity: HIGH`) and (2) in the Required Output format template (`- Severity: HIGH | MEDIUM | LOW`). If the HIGH severity marking were removed from Section 7 but retained in the output format template, this test would still PASS, providing false assurance that Section 7 is correctly configured. The test description claims to verify Section 7 content but the assertion cannot distinguish between the two occurrences.
- Severity: HIGH
- Action: Replace the broad pattern with one unique to Section 7. Use the full phrase `"fixture isolation is Severity: HIGH"` which only appears in Section 7 and cannot match the output format template. Alternatively, use `assert_line_contains` with the `"^### 7\. Test Isolation"` header as the anchor and `"Severity: HIGH"` as the content check.

#### INTEGRITY: Test 13 multi-name pattern fails on any reformatting
- File: tests/test_prompt_isolation_guardrails.sh:119
- Issue: Pattern `"CODER_SUMMARY.md.*REVIEWER_REPORT.md.*BUILD_ERRORS.md"` uses basic-regex `.*` which only matches when all three filenames appear on the same line. The content currently satisfies this (all three appear on one line in `test_audit.prompt.md`), but reformatting the example list across multiple lines for readability would silently break the test, producing a false failure. This fragility is disproportionate to what the assertion is trying to prove — it only needs to verify that the three example filenames are present in Section 7, not that they appear on one line.
- Severity: MEDIUM
- Action: Replace the single three-name pattern with three independent `assert_contains` calls, one per filename. This eliminates the line-ordering dependency while keeping the same intent.

#### SCOPE: Test 15 verifies pre-existing content unrelated to this feature
- File: tests/test_prompt_isolation_guardrails.sh:132
- Issue: Test 15 checks that `TEST_AUDIT_CONTEXT` appears in `prompts/test_audit.prompt.md`. This variable reference was present in the file before this task — it is part of pre-existing template infrastructure. The test would pass against the unmodified file and adds no coverage for the new Section 7 isolation guardrail.
- Severity: LOW
- Action: Remove Test 15. Its absence does not reduce coverage of the feature. If a test for `TEST_AUDIT_CONTEXT` is desired for infrastructure reasons, note its pre-existing nature in the description and move it to a general prompt-structure test file rather than this isolation-specific one.

#### COVERAGE: No section-positioning tests; new content could be misplaced
- File: tests/test_prompt_isolation_guardrails.sh
- Issue: All 15 tests verify string presence anywhere in the target file. Tests 2–6 for `prompts/tester.prompt.md` would pass even if the new isolation rules were accidentally inserted outside the `CRITICAL: Test Integrity Rules` section (e.g., appended at the end of the file). Similarly, Test 8 confirms `"### 7. Test Isolation"` exists, but no test confirms it appears after `"### 6. Scope Alignment"`, so Section 7 content relocated to a different position would pass all tests.
- Severity: LOW
- Action: Add one positional test per file. For the tester prompt: verify `"NEVER read live repo artifact files"` appears within the CRITICAL block (between `^## CRITICAL: Test Integrity Rules` and the next `^##` heading). For the audit prompt: verify `"### 7. Test Isolation"` appears after `"### 6. Scope Alignment"`.

#### COVERAGE: No negative tests
- File: tests/test_prompt_isolation_guardrails.sh
- Issue: All 15 assertions are presence-only checks. There are no tests verifying that deprecated or incomplete text is absent. A notable gap: no test verifies the audit prompt's rubric header now reads "Seven-Point" (or equivalent) rather than the original "Six-Point Audit Rubric". Adding a "Seven-Point" header or updating the section count could silently fail without a negative test.
- Severity: LOW
- Action: Add a test verifying the old "Six-Point Audit Rubric" header no longer appears in `prompts/test_audit.prompt.md` (the heading was not changed but the rubric now has 7 points). If the header was updated, test that "Six-Point" is absent. If not changed, document that the heading is intentionally stale so future editors know.
