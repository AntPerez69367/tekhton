## Test Audit Report

### Audit Summary
Tests audited: 1 file, 11 test functions
Verdict: PASS

### Findings

#### COVERAGE: Test asserts known-broken behavior as a behavioral contract
- File: tests/test_m111_downstream_dep_unblock.sh:121-146 (Sections 1–3), 176-178 (Section 4)
- Issue: Five of the eleven assertions verify that a downstream milestone (m03) remains
  permanently blocked after all sub-milestones complete — because _split_apply_dag() does
  not rewrite downstream dep references from parent_id to last_sub_id, and dag_deps_satisfied()
  requires status == "done" rather than accepting "split". The test header honestly labels
  this as "Current behavior (known limitation, M111 drift observation)" but the individual
  assertions carry no per-line annotation. These assertions pass today because the bug is
  still present. When the downstream dep-unblock is implemented (either option (a) or (b)
  from the test header), all five will flip to FAIL, giving the false appearance of a
  regression in CI.
- Severity: MEDIUM
- Action: Add a `# BUG(future): invert/remove when downstream dep-unblock is implemented`
  comment on each assertion that verifies broken behavior:
    line 109-110 (m03 NOT in frontier — dep is split)
    line 127-128 (m03 NOT in frontier after m02.1 done)
    line 141-143 (m03 NOT in frontier after both subs done)
    line 145-146 (dag_deps_satisfied(m03) returns false)
    line 177-178 (m03 depends_on is still 'm02' after split)
  This makes the maintenance obligation visible without changing test behavior now.

#### COVERAGE: split_milestone exit code silently discarded before dependent assertions
- File: tests/test_m111_downstream_dep_unblock.sh:172
- Issue: `rc split_milestone "2" "${TMPDIR}/CLAUDE.md" || true` discards the return code.
  If split_milestone exits non-zero for any reason (missing template file, missing venv,
  etc.), the test continues silently. The assertion at line 177 ("m03 depends_on is still
  'm02' after split") would then pass trivially — the manifest was never updated, so m03_deps
  is still "m02" from the pre-split load. The m02_status assertion at line 181 provides a
  partial guard (it would fail since m02 was never marked "split"), but the failure message
  would report a status mismatch with no indication that split_milestone itself failed,
  making root-cause diagnosis harder.
- Severity: LOW
- Action: Capture and assert on the exit code before the dependent checks:
    `rc split_milestone "2" "${TMPDIR}/CLAUDE.md"; split_rc=$?`
    `assert "split_milestone succeeded (prereq for Section 4 assertions)" "$split_rc"`
  This produces a clearly labeled failure rather than a confusing status mismatch.

#### None — Assertion Honesty
All assertions derive expected values from real function outputs against controlled fixtures.
No hard-coded magic values unrelated to implementation logic. No tautological assertions.

#### None — Implementation Exercise
Tests source and directly invoke `dag_get_frontier`, `dag_deps_satisfied`, `dag_set_status`,
`split_milestone`, and `load_manifest` from the real implementation files. The mock
`_call_planning_batch` is minimal and only substitutes the external agent call — all DAG
array manipulation and frontier logic executes unmodified.

#### None — Test Weakening
The tester added only a new file. No existing test files were modified this run.

#### None — Isolation
All fixtures are written to `$TMPDIR` with `trap 'rm -rf "$TMPDIR"' EXIT`. No mutable
project-state files (.tekhton/, .claude/logs/, pipeline state files) are read or depended on.
Test outcome is fully independent of prior pipeline runs or repo state.

#### None — Naming
Test assertion descriptions are specific and outcome-encoded, e.g.:
  "m03 NOT in frontier: dep m02 is 'split', not 'done'"
  "dag_deps_satisfied(m03) returns false: m02 must be 'done', not 'split'"
  "m03 enters frontier when m02 dep is 'done'"

#### None — Scope Alignment
No orphaned imports or stale references detected. The freshness sample files
(test_draft_milestones_validate.sh, test_draft_milestones_write_manifest.sh,
test_drain_pending_inbox.sh) are unrelated to M111 changes and are not subject to this
audit per the audit context rules.
