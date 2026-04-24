## Test Audit Report

### Audit Summary
Tests audited: 6 files, 114 test assertions (per tester report) + 2 freshness-sample files (scope-checked only)
Verdict: CONCERNS

---

### Findings

#### INTEGRITY: Subshell counter isolation silently swallows failures
- File: tests/test_common_box_edge_cases.sh:33-99
- Issue: Sections 1 and 2 (five individual test cases) run inside `( ... )` subshells to isolate `LANG`/`LC_ALL` environment state. The `pass()` and `fail()` functions increment `PASS` and `FAIL` inside those subshells, but subshell variable changes never propagate to the parent shell. The parent's `FAIL` counter stays 0 regardless of subshell outcomes. The exit-gate at line 224 (`[[ "$FAIL" -gt 0 ]] && exit 1`) therefore cannot fire on any failure in the five affected test cases. A regression in `_is_utf8_terminal` or `_setup_box_chars` would print "FAIL: ..." to stdout while the test file exits 0. This is confirmed by the tester's own count: they report 11 passed — exactly the 11 non-subshell assertions — while the 5 subshell increments are silently discarded.
- Severity: HIGH
- Action: Restructure each subshell block to invoke the function under test in a subshell for environment isolation but track pass/fail in the parent. Pattern: capture the exit code via `( export LANG=...; _is_utf8_terminal ); rc=$?` then call `pass`/`fail` in the parent based on `$rc`. This preserves LANG isolation while keeping all counter updates in the parent.

#### EXERCISE: Test never calls validate_config() — only tests grep pattern in isolation
- File: tests/test_validate_config_design_file.sh:1-159
- Issue: The file header and test names claim to verify "checks 6a and 6b in lib/validate_config.sh", but the file never sources `lib/validate_config.sh` and never calls `validate_config()`. Instead it independently re-implements the same grep pattern (line 44) and the same bash conditional (line 57) and verifies those expressions directly. This creates false coverage: if someone updates the grep pattern inside `validate_config.sh` — to fix a matching bug or add an edge case — this test will not detect the regression because it is testing its own hardcoded copy of the pattern. The `_is_utf8_terminal` stub at line 27 is defined but unused (it would only be needed if `validate_config.sh` were sourced).
- Severity: MEDIUM
- Action: Source `lib/validate_config.sh`, set up a full `$PROJECT_DIR` fixture with a `pipeline.conf` containing empty and directory-path `DESIGN_FILE` variants, call `validate_config()`, and assert that the expected warning lines appear in its output. The current pattern-unit tests can be kept as supplementary, but at least one end-to-end call through the real function is required to close the exercise gap.

#### ISOLATION: TMPDIR shadowing not fixed consistently across modified files
- File: tests/test_quota.sh:19, tests/test_quota_retry_after_integration.sh:22
- Issue: Both files assign `TMPDIR=$(mktemp -d)`, overriding the standard `$TMPDIR` environment variable that POSIX tools use as the default temp directory. The identical issue was fixed during this run in `test_draft_milestones_validate_lint.sh` (renamed to `TEST_TMPDIR`) but the fix was not applied to these two files. Any code path called during the test that invokes `mktemp` without an explicit prefix will create files inside the test's temp directory, which is removed by the `trap ... EXIT`. In practice the immediate risk for test_quota.sh is low (quota_probe.sh supplies explicit mktemp prefixes), but the inconsistency leaves a latent hazard and contradicts the fix already applied to the sibling file.
- Severity: MEDIUM
- Action: Rename `TMPDIR` to `TEST_TMPDIR` at lines 19 and 22, update all downstream variable references in each file (`PROJECT_DIR`, `LOG_DIR`, `LOG_FILE`, `PIPELINE_STATE_FILE`, `TEKHTON_SESSION_DIR`, `CAUSAL_LOG_FILE`, etc.), consistent with the fix applied to `test_draft_milestones_validate_lint.sh`.

#### COVERAGE: Integration grep-count assertion too weak to catch partial-match regressions
- File: tests/test_validate_config_design_file.sh:136
- Issue: The integration fixture (lines 112-131) contains four distinct empty-DESIGN_FILE variants (`""`, `''`, `"    "`, and `"" # comment`). The assertion at line 136 only checks `empty_count -ge 1`. A broken pattern that matches only the simplest variant would pass while silently missing the other three.
- Severity: LOW
- Action: Change the assertion to `[[ "$empty_count" -ge 3 ]]` (or the exact count matching the number of empty-string fixture lines the pattern is expected to match) so that partial-match regressions surface.

#### COVERAGE: Content-padding length assertion uses a loose lower-bound
- File: tests/test_common_box_edge_cases.sh:138
- Issue: The assertion `[[ ${#output} -ge 40 ]]` for `_print_box_line "|" 40 "Hello"` accepts any output of 40 or more characters. Since the output includes a trailing newline and two border characters the actual length is 43; the loose bound would pass even if padding were widened to 100. The companion empty-content test at line 149 uses exact equality (`-eq 42`), which is the stronger form.
- Severity: LOW
- Action: Replace with `[[ ${#output} -eq 43 ]]` (1 border + 2 spaces + 38-char padded content + 1 border + 1 newline) to match the exact contract of the `printf '%-*s'` call.

---

### Notes on Shell-Detected Orphans

All STALE-SYM entries in the pre-verified list (`:`, `bash`, `cat`, `cd`, `chmod`, `echo`, `exit`, `grep`, `mktemp`, `source`, `trap`, `true`, etc.) are POSIX shell builtins and standard Unix utilities, not user-defined project functions. These are false positives from the orphan detector's inability to distinguish system commands from project symbols. No action required on any of them.

---

### Freshness Sample (scope check only — no full functional audit)

- `tests/test_indexer_infer_counterparts.sh`: Sources `lib/indexer_helpers.sh` (listed as modified this run). Quick scope check found no renamed or removed symbols; function `infer_test_counterparts` still present. No scope issues detected.
- `tests/test_indexer_line_ceiling.sh`: References `lib/indexer.sh` structural properties. `indexer.sh` was not listed as modified this run. No scope drift detected.
