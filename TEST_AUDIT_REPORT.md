## Test Audit Report

### Audit Summary
Tests audited: 4 files, 43 test functions
Verdict: PASS

### Implementation Baseline Note
`CODER_SUMMARY.md` is absent. The audit context states "Implementation Files Changed: none."
Git history confirms `lib/detect.sh` was last modified in commit `4ce901d` (the immediately
prior pipeline session, labeled as a health-scoring fix) — that commit added the CLAUDE.md
fallback to `detect_languages()` at lines 107–126. The 4 new test files test that already-
committed implementation. `tests/test_detect_languages.sh` (the committed baseline file)
already contains a basic CLAUDE.md fallback test at lines 222–250.

---

### Findings

#### SCOPE: Tester created 4 new files instead of adding to the specified file
- File: tests/test_detect_languages_fallback_guard.sh, tests/test_detect_languages_multiple_langs.sh, tests/test_detect_languages_fallback_prose.sh, tests/test_detect_languages_edge_cases.sh
- Issue: The task specification explicitly instructs: "Add a test case to
  `tests/test_detect_languages.sh` (the existing language detection test file)." The tester
  instead created 4 separate new files and did not touch `tests/test_detect_languages.sh`.
  That existing file already contains a CLAUDE.md fallback section at lines 222–250 (committed
  in a prior session) which satisfies the task's minimal requirement. The 4 new files provide
  supplementary depth coverage and are not orphaned — they test real, committed behavior —
  but the prescribed approach was not followed.
- Severity: MEDIUM
- Action: No changes required to the 4 new files; their content is valid. For future audit
  traceability, add a comment to `tests/test_detect_languages.sh` pointing to the supplementary
  files, e.g. `# Extended CLAUDE.md fallback coverage: see test_detect_languages_fallback_*.sh`

#### NAMING: Misleading test name and mismatched fixture in prose fallback Test 4
- File: tests/test_detect_languages_fallback_prose.sh:183
- Issue: The test is titled "Case-insensitive extraction doesn't match partial words" and its
  inline comment says "This section mentions 'python' in context but shouldn't match
  'typescript' in 'typescript-like'" — but the CLAUDE.md fixture contains neither `python`
  as a standalone word in prose nor the compound `typescript-like`. The actual fixture tests
  that Go and Kotlin are detected from plain prose with no false positives from other language
  names. The intent the name describes (partial-word guard) is untested. The assertions that
  exist are correct against the actual fixture, but the test is misdescribed.
- Severity: MEDIUM
- Action: Either (a) rename to "prose_fallback_no_false_positives" and remove the misleading
  comment, or (b) add a fixture line like "Uses a TypeScript-like syntax for macros." and
  verify that TypeScript is or is not detected, to actually test the stated partial-word
  scenario.

#### COVERAGE: Dead `else` branch in prose fallback Test 4 false-positive check
- File: tests/test_detect_languages_fallback_prose.sh:220–230
- Issue: The false-positive assertion uses a two-layer conditional:
    if grep -qE "^(typescript|python|...)"; then
        unexpected=$(echo "$word_langs" | grep -vE "^(go|kotlin)")
        if [[ -n "$unexpected" ]]; then fail; else pass; fi
    else
        pass
    fi
  The outer `grep` returns true only if an unexpected language is present. In that case, the
  inner `$unexpected` will always be non-empty (the outer match is a subset of what `grep -v`
  preserves). The inner `else pass` branch is dead code. The assertion is not wrong in
  practice — the outer `else pass` is where real coverage lives — but the structure is
  misleading about what is actually being checked.
- Severity: LOW
- Action: Simplify to a single-layer check:
    if echo "$word_langs" | grep -qE "^(typescript|python|ruby|php|haskell|elixir|dart|swift|rust|java|javascript)\|"; then
        fail "Unexpected language detection: $word_langs"
    else
        pass "No false positive language detection"
    fi

#### NAMING: Hardcoded expected language count without cross-reference
- File: tests/test_detect_languages_edge_cases.sh:231
- Issue: `expected_count=14` is asserted against `wc -l` output with no connection to the
  implementation. The comment (line 201) correctly lists all 14 languages from `_known_langs`
  in `detect.sh`, but if the implementation ever adds or removes a language, this test fails
  with "Expected 14 languages, got N" with no indication of which language changed.
- Severity: LOW
- Action: Add a comment on the `expected_count` line:
  `expected_count=14  # sync with _known_langs at lib/detect.sh:111`
  and consider listing the expected language names in a variable for a diff-friendly failure
  message.

---

### Per-File Integrity Summary

| File | Assertions Honest | Fixtures Isolated | Calls Real Code | No Weakening | Verdict |
|------|-------------------|-------------------|-----------------|--------------|---------|
| test_detect_languages_fallback_guard.sh | PASS | PASS (mktemp + trap) | PASS (sources detect.sh) | n/a (new file) | PASS |
| test_detect_languages_multiple_langs.sh | PASS | PASS (mktemp + trap) | PASS (sources detect.sh) | n/a (new file) | PASS |
| test_detect_languages_fallback_prose.sh | PASS | PASS (mktemp + trap) | PASS (sources detect.sh) | n/a (new file) | PASS with notes |
| test_detect_languages_edge_cases.sh | PASS | PASS (mktemp + trap) | PASS (sources detect.sh) | n/a (new file) | PASS |

None of the 4 files read live project files, pipeline logs, or mutable state artifacts.
All fixtures are constructed in temp directories with `trap 'rm -rf "$TEST_TMPDIR"' EXIT`.
All assertions verify outputs from real `detect_languages()` calls against controlled inputs.
No existing tests were modified.

### Implementation Verification Summary

All assertions were traced against `lib/detect.sh` (lines 107–126, the CLAUDE.md fallback).

**Fallback guard** (`test_detect_languages_fallback_guard.sh`): The guard condition
`[[ -z "$_detected_output" ]]` at line 107 correctly suppresses the CLAUDE.md path when
file-based detection produces output. The TypeScript detection in Test 1 is driven by
`package.json` + `tsconfig.json` presence (lines 28–30) producing `lang_manifest[typescript]`,
combined with `touch`-created `.ts` files counted by `_count_source_files`. With
`has_manifest="package.json"` and `source_count=2`, the confidence formula at lines 89–90
resolves to `high`. All assertions are derivable from implementation logic. ✓

**Multiple languages** (`test_detect_languages_multiple_langs.sh`): The bullet grep
`grep -ioE "^[[:space:]]*-[[:space:]]+(${_known_langs})"` with `-o` outputs only the matching
portion, correctly stripping parenthetical descriptions like `- TypeScript (tools)` down to
`- TypeScript`. The subsequent `sed` strips the `- ` prefix. Case normalization via `tr` is
applied after extraction. All assertions about output format (`lang|low|CLAUDE.md`) and
case normalization are correct. ✓

**Prose fallback** (`test_detect_languages_fallback_prose.sh`): The secondary grep
`grep -oiE "(${_known_langs})" | sort -u` fires only when the bullet grep yields nothing.
The `sort -u` correctly deduplicates repeated mentions (Test 3). The prose fallback in the
mixed-format test (Test 2) is suppressed because the bullet grep succeeds on `- Kotlin for
Android app` (the `-o` match stops at `Kotlin`, not the full bullet text). ✓

**Edge cases** (`test_detect_languages_edge_cases.sh`): The `sed` range
`/^### 1\. Project Identity/,/^###/` produces an empty `_identity_block` when the heading
is absent (Test 2) or the section contains no language keywords (Tests 1, 3). The `C#`
normalization test (Test 4) is correct: `grep -ioE` matches `C#` case-insensitively, `tr`
lowercases it to `c#`, and the output is `c#|low|CLAUDE.md`. The 14-language fixture
(Test 6) correctly exercises all entries in `_known_langs`. ✓

**Assertion honesty (PASS):** No hard-coded values bypass actual function execution.
No identity assertions or always-true checks found.

**Test weakening (PASS):** No existing tests were modified. All 4 files are new.

**Test isolation (PASS):** No test reads live pipeline artifacts, build reports, or
project-state files outside the per-test temp directory.
