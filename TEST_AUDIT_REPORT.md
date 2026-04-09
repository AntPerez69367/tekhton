## Test Audit Report

### Audit Summary
Tests audited: 1 file, 33 test functions (45 pass/fail assertions)
Verdict: PASS

### Findings

#### COVERAGE: M69 migration trigger path in rescan_project never exercised
- File: tests/test_rescan.sh:99–144
- Issue: The M69 migration check at rescan.sh:51–55 (`if [[ ! -f "${project_dir}/.claude/index/meta.json" ]]`) is never directly exercised as its own test. The two tests modified for M69 (non-git dir, no Scan-Commit) both CREATE a meta.json to bypass this path and reach their intended code branches. The scenario "PROJECT_INDEX.md exists, meta.json absent → M69 migration full crawl" has no dedicated test.
- Severity: MEDIUM
- Action: Add a test with a PROJECT_INDEX.md but no `.claude/index/meta.json`. Assert `CRAWL_PROJECT_CALLED -ge 1`. Comment should note it exercises the M69 migration path specifically (rescan.sh:51–55).

#### COVERAGE: _extract_scan_metadata structured-data path (M69) not tested
- File: tests/test_rescan.sh:338–381
- Issue: `_extract_scan_metadata` prefers `.claude/index/meta.json` over HTML comment parsing (rescan_helpers.sh:122–139). Every test in this section creates its index file at `${TEST_TMPDIR}/meta_test_index.md`, so `project_dir = $TEST_TMPDIR`. No `.claude/index/meta.json` exists there, so all three assertions (Scan-Commit, File-Count, Last-Scan) exercise only the legacy fallback path. If the structured-data branch had a regression (wrong JSON key name, bad sed), these tests would not detect it.
- Severity: MEDIUM
- Action: Add a test that creates `${TEST_TMPDIR}/.claude/index/meta.json` with known values and verifies that `_extract_scan_metadata` reads `scan_commit`, `file_count`, and `scan_date` from it (the M69 preferred path). Existing legacy-path tests should remain unchanged.

#### COVERAGE: _extract_sampled_files structured-data path (M69) not tested
- File: tests/test_rescan.sh:386–441
- Issue: `_extract_sampled_files` prefers `.claude/index/samples/manifest.json` (rescan_helpers.sh:203–208) and falls back to `grep '^### '` only when absent. Both tests place the index in `$TEST_TMPDIR` with no `samples/manifest.json`, so they exercise only the legacy grep path. The M69 manifest.json path is untested.
- Severity: MEDIUM
- Action: Add a test that creates `.claude/index/samples/manifest.json` with `"original"` entries and verifies that `_extract_sampled_files` correctly extracts them.

#### COVERAGE: Incremental update path (_update_index_sections) not tested
- File: tests/test_rescan.sh (no test present)
- Issue: The incremental update branch of `rescan_project` — reached when significance is "trivial" or "moderate" and a valid scan commit exists — is never exercised. This calls `_update_index_sections` (rescan.sh:109), which drives M69 structured-file regeneration (`_emit_tree_txt`, `_emit_inventory_jsonl`, `_emit_dependencies_json`, etc.). Every `rescan_project` test triggers a full-crawl fallback, so this code path has zero coverage in the audited file.
- Severity: MEDIUM
- Action: Verify whether `tests/test_index_structured.sh` (new file visible in git status, not in audit scope) covers `_update_index_sections`. If not, add a test in `test_rescan.sh` that sets up a git repo, commits a known scan commit, introduces a trivial change, and asserts that `crawl_project` is NOT called and that the index is updated incrementally.

#### SCOPE: Audit context lists test_rescan.sh twice; test_index_structured.sh omitted
- File: (audit configuration)
- Issue: The audit context lists `tests/test_rescan.sh` twice and does not list `tests/test_index_structured.sh`, which is a new file in the working tree likely covering M69 structured-index behavior. The coverage gaps above may be partially addressed by that file.
- Severity: LOW
- Action: Re-run audit with `tests/test_index_structured.sh` included to determine if the MEDIUM coverage findings above are already covered elsewhere.
