## Test Audit Report

### Audit Summary
Tests audited: 1 file, 14 test assertions
Verdict: PASS

### Findings

#### INTEGRITY: Overly broad total_lines assertion in fallback path
- File: tests/test_rescan_metadata.sh:176
- Issue: The fixture creates exactly 2 files with 5 lines each (total=10), but the
  assertion checks `meta_tl2 > 0 && != 999`. This passes for any non-zero, non-stale
  value — it would not catch a bug where only one file was counted (total=5) or where
  wc -l was applied to only one of the two files. The exact expected value is known
  from the fixture.
- Severity: MEDIUM
- Action: Replace with `[[ "$meta_tl2" == "10" ]]` to pin the exact value derived
  from the fixture (2 files × 5 lines each).

#### INTEGRITY: Loose file_count floor in Section 3 initial crawl assertion
- File: tests/test_rescan_metadata.sh:204-209
- Issue: Section 3 commits exactly 4 files (src/a.sh, src/b.sh, src/c.sh, README.md)
  then asserts `initial_fc >= 1`. This passes even if only 1 file is indexed — a
  regression that silently drops 3 of 4 files from the crawl would go undetected.
  The exact expected count is known from the fixture setup.
- Severity: MEDIUM
- Action: Replace with `[[ "$initial_fc" == "4" ]]` to pin the exact expected count.
  The fixture is a clean git repo with no extraneous tracked files, making an exact
  assertion safe.

#### INTEGRITY: Unconditional pass() inflates reported test count
- File: tests/test_rescan_metadata.sh:163-164
- Issue: `pass "_record_scan_metadata completes without crash when inventory.jsonl absent"`
  is called unconditionally on the line immediately after invoking the function. With
  `set -euo pipefail` in effect, a non-zero exit already aborts the script — this
  `pass()` adds no assertion value but increments PASS by 1, inflating the count from
  13 real assertions to 14 and misrepresenting test depth to readers.
- Severity: LOW
- Action: Remove the unconditional `pass()` on line 164. The substantive assertions
  on lines 167-180 are sufficient to verify this code path.

#### COVERAGE: Section 2 omits PROJECT_INDEX.md HTML comment verification
- File: tests/test_rescan_metadata.sh:130-180
- Issue: Section 1 (JSONL present) verifies all four `sed -i` writes in
  `_record_scan_metadata` — the `File-Count`, `Total-Lines` HTML comments, and the
  visible `**Files:** | **Lines:**` line. Section 2 (no JSONL fallback) only checks
  meta.json. The six sed calls in rescan_helpers.sh:185-192 that update
  PROJECT_INDEX.md are not exercised for the fallback branch. A regression that breaks
  the sed path specifically when inventory.jsonl is absent would not be caught.
- Severity: LOW
- Action: After the existing fallback assertions, add:
  `grep -q "<!-- File-Count: 2 -->" "${PROJ2}/PROJECT_INDEX.md"` and
  `grep -q "Files.*2.*Lines" "${PROJ2}/PROJECT_INDEX.md"`.

#### SCOPE: CODER_SUMMARY.md absent — cross-reference incomplete
- File: tests/test_rescan_metadata.sh (audit-wide)
- Issue: CODER_SUMMARY.md does not exist in the repository. The required reading for
  this audit specifies it as the primary record of what implementation files changed
  and why. Git status shows lib/crawler_emit.sh as new and five existing files
  modified (crawler.sh, crawler_inventory.sh, rescan.sh, rescan_helpers.sh, etc.).
  The test sources crawler.sh → crawler_emit.sh and exercises _emit_meta_json,
  _emit_inventory_jsonl, and _record_scan_metadata — the M67 emitters are covered.
  Scope appears aligned based on direct implementation reading, but cannot be fully
  confirmed without the coder summary.
- Severity: LOW
- Action: Ensure the coder agent produces CODER_SUMMARY.md so future audits can
  formally cross-reference changed files against tested code paths.

### No Issues Found In These Categories

**ISOLATION**: All fixtures are created in $TEST_TMPDIR and cleaned up via trap. No
test reads from mutable project state files (pipeline logs, REVIEWER_REPORT.md,
BUILD_ERRORS.md, etc.). Clean.

**EXERCISE**: All tests invoke real implementation functions (_record_scan_metadata,
crawl_project, rescan_project) against real git repositories constructed in temp
directories. No mocking is used. The fixture design in Section 1 — where the JSONL
deliberately contradicts the actual file state (2 phantom files, 300 claimed lines
vs 1 real file with 3 lines) — is an effective technique to prove which code path
fires.

**WEAKENING**: New test file. No existing tests were modified.

**NAMING**: Section echo headers and pass/fail message strings are descriptive of
both the scenario and the expected outcome. Acceptable for a flat bash test harness.
