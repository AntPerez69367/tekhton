## Test Audit Report

### Audit Summary
Tests audited: 2 files, 8 test functions (4 per file)
Verdict: CONCERNS

---

### Findings

#### INTEGRITY: Test 3 dual-path assertion masks guard false-positive regression
- File: tests/test_plan_interview_tool_write_guard.sh:218-228
- File: tests/test_plan_generate_tool_write_guard.sh:247-256
- Issue: Both Test 3 blocks accept two mutually exclusive pass conditions. The
  second branch fires when the tool-written short file's content (e.g. `"# Short"`)
  is still the first line — the comment labels this "guard threshold not met".
  However, this state is only reachable if the guard *incorrectly fired*: without
  guard activation, `printf '%s\n' "$design_content"` overwrites the tool-written
  file with the summary text, so `"# Short"` would never remain as the first line.
  A regression that lowers the threshold constant (e.g., `_disk_lines -gt 5`
  instead of `_disk_lines -gt 20`) would trigger a false-positive guard fire on a
  10-line file, leave the tool-written content on disk, and the second branch would
  accept it with a pass. The dual-path means the test cannot detect a false-positive
  guard trigger on short files.
- Severity: HIGH
- Action: Remove the else-if branch in Test 3 of both files
  (test_plan_interview lines 221-227, test_plan_generate lines 250-255). The only
  valid pass condition is that the summary text was written over the tool file:
  `grep -q "created with 10 lines"`. If that does not match, the test must fail.

#### INTEGRITY: Test 3 pass message is logically inverted
- File: tests/test_plan_interview_tool_write_guard.sh:223
- File: tests/test_plan_generate_tool_write_guard.sh:252
- Issue: The second-branch pass message reads "10-line file remains from
  tool-write (guard threshold not met)". The parenthetical is backwards: "guard
  threshold not met" means the guard did NOT fire, which means the file should
  have been overwritten — the tool-written content cannot remain. The message
  describes the opposite of the state it accepts, which would confuse any developer
  reading a passing test output.
- Severity: HIGH
- Action: This finding is resolved by removing the second branch entirely
  (same fix as above). No separate action needed.

#### COVERAGE: No test for empty batch output (null-run error path)
- File: tests/test_plan_interview_tool_write_guard.sh (missing test case)
- File: tests/test_plan_generate_tool_write_guard.sh (missing test case)
- Issue: Both implementations have an explicit error path when
  `_call_planning_batch` returns empty output and no file is written to disk
  (stages/plan_interview.sh:379-390, stages/plan_generate.sh:131-136). Both emit
  `warn "Synthesis produced no output"` and return 1. No test exercises this path.
  A regression that silently swallows batch output would go undetected.
- Severity: MEDIUM
- Action: Add a Test 5 to each file: mock returns empty string and writes nothing
  to disk. Assert that the output file does not exist and the function returns
  non-zero.

#### COVERAGE: Guard non-fire when captured output IS heading-started and prior disk file exists
- File: tests/test_plan_interview_tool_write_guard.sh (edge case absent from Test 2)
- File: tests/test_plan_generate_tool_write_guard.sh (edge case absent from Test 2)
- Issue: Test 2 ("Normal case") verifies that heading-started captured output is
  written correctly, but only when no file pre-exists on disk. The guard's outer
  condition (`[[ -f "$design_file" ]]`) is trivially unsatisfied in Test 2, so the
  inner heading-check branch is never reached. If the outer condition were
  accidentally removed, Test 2 would still pass. The case of heading-captured
  output with a substantive file already on disk is not covered.
- Severity: LOW
- Action: Extend Test 2 (or add Test 2b) to pre-seed a substantive disk file
  before calling the function. Verify the guard does not fire and the captured
  heading-started output is correctly written.

#### SCOPE: CODER_SUMMARY.md absent; audit context "Implementation Files Changed: none" contradicts git status
- File: CODER_SUMMARY.md (absent)
- Issue: The audit context states "Implementation Files Changed: none", but git
  status shows M on stages/plan_interview.sh, stages/plan_generate.sh,
  prompts/plan_interview.prompt.md, and prompts/plan_generate.prompt.md. The guard
  logic tested by these files is present and correct in the implementation:
  - stages/plan_interview.sh:345-360 — tool-write guard
  - stages/plan_generate.sh:80-96   — tool-write guard
  - prompts/plan_interview.prompt.md:37 — "Output DESIGN.md content directly as
    text. Do NOT use any tools to write files"
  - prompts/plan_generate.prompt.md:221 — matching directive for CLAUDE.md
  No orphaned imports, stale function references, or misaligned assertions were
  found. Tests correctly target the real implementation.
- Severity: LOW
- Action: Generate CODER_SUMMARY.md documenting the four modified files and the
  guard logic added to each. No test changes required for this finding.
