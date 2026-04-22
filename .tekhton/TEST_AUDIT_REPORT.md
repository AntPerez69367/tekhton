## Test Audit Report

### Audit Summary
Tests audited: 5 files, 26 test functions
Verdict: CONCERNS

---

### Findings

#### EXERCISE: test_tui_write_suppression.sh — write suppression behavior still untested after rework
- File: tests/test_tui_write_suppression.sh:24–131
- Issue: The prior audit flagged this HIGH because no tests called real implementation
  code. The rework added `test_tui_stage_end_uses_suppress` (lines 47–81), which
  sources `lib/tui.sh` and calls real `tui_stage_end` with an open substage — an
  improvement. However the HIGH criterion from the prior round still holds: if the
  suppression gate at `lib/tui.sh:267` were deleted:

  ```bash
  (( ${_TUI_SUPPRESS_WRITE:-0} > 0 )) && return 0   # line 267
  ```

  all four tests would still pass. `test_tui_stage_end_uses_suppress` asserts only
  that `_TUI_SUPPRESS_WRITE == 0` after `tui_stage_end` returns — that is, it verifies
  the counter is *balanced* (bumped at `tui_ops.sh:225`, decremented at line 244), not
  that the gate *actually suppressed intermediate writes*. Without a write-count probe,
  the test cannot distinguish "gate held, one write" from "gate absent, three writes,
  counter still balanced." The TESTER_REPORT's claim that the tests "verify that
  `_TUI_SUPPRESS_WRITE` gate blocks writes at lib/tui.sh:267" overstates what
  `test_tui_stage_end_uses_suppress` does.

  The remaining three tests (`test_suppress_gate_logic`, `test_suppress_counter_arithmetic`,
  `test_suppress_unset_default`) test inline bash arithmetic semantics — they do not call
  any TUI function and add no behavioral coverage for the suppression mechanism.
- Severity: HIGH
- Action: In `test_tui_stage_end_uses_suppress`, instrument `_tui_write_status` to
  count calls before invoking `tui_stage_end`, then assert the count is exactly 1.
  Open a substage beforehand (as the test already does) so that without suppression
  three writes would occur (auto-close substage, tui_finish_stage, final). With
  suppression the count must be 1. The arithmetic auxiliary tests may be retained
  as documentation, but the behavioral property must be verified against the real gate.

#### EXERCISE: test_milestone_split_path_traversal.sh — source inspection only, runtime guard not exercised
- File: tests/test_milestone_split_path_traversal.sh:19–116
- Issue: The prior audit flagged this HIGH because all tests re-implemented the guard
  inline and a removed guard would not cause any failure. The rework switched to source
  inspection (`grep`): tests 1–3 now grep for the guard pattern, the error message, and
  the relative line ordering. These three tests **would fail** if the guard block were
  removed from `_split_flush_sub_entry`, addressing the prior HIGH criterion.

  The remaining concern is that no test exercises the guard at runtime. Tests 4–5
  (`test_filename_pattern_matching`, `test_traversal_patterns_rejected`) still test the
  `[[ "$filename" == */* ]]` pattern inline rather than through the function. The
  source inspection tests verify structure (guard exists, wording is correct, position
  is before the write) but cannot catch behavioral regressions such as a guard that
  is present in source but never reached in the call path, or a `return 1` that is
  accidentally swapped for `return 0`. Given that `_split_flush_sub_entry` is
  locally scoped inside `_split_apply_dag`, full runtime testing requires scaffolding
  the parent function with stub dependencies.
- Severity: MEDIUM
- Action: Add a runtime test that sources `lib/milestone_split_dag.sh` with the
  required stubs (`dag_number_to_id`, `dag_get_file`, `_dag_milestone_dir`, `_slugify`,
  `error`) and calls `_split_apply_dag` with crafted split output containing a
  traversal payload in a milestone title (a slug that produces `../`). Assert the
  function returns non-zero AND that no file is written to the milestone dir. If
  the scaffolding cost is too high, add a comment in the test explaining the
  constraint and marking the structural tests as "existence checks, not behavioral."

#### NAMING: test_emit_event_always_guarded overstates coverage
- File: tests/test_emit_event_guard_consistency.sh:112–146
- Issue: The test name and the unconditional `pass` at line 145 claim "emit_event
  calls are protected by guard patterns in both files." The test actually only
  verifies that each file has at least one `declare -f emit_event` line (`-gt 0`).
  It does not verify every `emit_event` call site is inside a guard block. Counting
  `grep -c 'emit_event'` includes the guard lines themselves (lines 43, 69, 85, 105,
  132 in `coder_prerun.sh` have both `declare -f emit_event` and `emit_event "..."` on
  adjacent lines), making the `coder_calls` count an overcount of actual call sites.
  The `pass` line is reached unconditionally whenever `coder_guards > 0` AND
  `tester_guards > 0`, regardless of how many unguarded calls exist.
- Severity: LOW
- Action: Rename to `test_emit_event_guards_exist` to match what is actually
  verified. If per-call coverage is required, build per-site analysis: extract
  each `emit_event` call line number and check that each is preceded by a
  `declare -f emit_event` guard in the same conditional block.

---

### Non-Findings (passing review)

**test_tui_substage_unused_args.sh** — No issues. Sources `lib/tui.sh`, which
transitively loads `lib/tui_ops_substage.sh`. All seven tests call the real
`tui_substage_begin` and `tui_substage_end` with `_tui_write_status` mocked to a
no-op. Assertions check actual globals (`_TUI_CURRENT_SUBSTAGE_LABEL`,
`_TUI_CURRENT_SUBSTAGE_START_TS`). Covers: model-arg present, model-arg absent,
label/verdict-arg present, no-arg, global-pollution guard, multi-call sequencing,
and inactive passthrough. All assertions grounded in real implementation behavior.

**test_tui_ops_idle_ordering.sh** — NAMING rework accepted. `test_run_op_write_occurs_after_command`
accurately describes the sanity check (at least one write after command). The
ordering property is covered by `test_run_op_idle_ordering`, which correctly
intercepts both `tui_substage_begin` (verifying `_TUI_AGENT_STATUS == "working"`)
and `tui_substage_end` (capturing `_TUI_AGENT_STATUS == "idle"`) against the real
`run_op` at `lib/tui_ops.sh:107–146`. Exit code preservation (tests 3–4) and
inactive passthrough (test 2) are correctly scoped.

**test_emit_event_guard_consistency.sh** (tests 1–4) — The `declare -f` logic check,
`coder_prerun` grep, `tester_fix` grep, and consistency check are sound. Source
files are version-controlled and deterministic (not mutable pipeline artifacts), so
reading them directly is appropriate. Pattern-verified assertions in tests 2–4 would
fail if the canonical guard form were changed. The prior LOW finding (warn → fail)
is confirmed fixed: the test now calls `fail` on guard-absent conditions.

**test_tui_write_suppression.sh — counter balance test** — `test_tui_stage_end_uses_suppress`
is a genuine improvement over the prior version: it calls real `tui_stage_end` with
a live substage open and verifies the counter lifecycle. This is a necessary (but
not sufficient) behavioral test. Progress is real; the remaining HIGH gap is the
missing write-count assertion.

**Freshness samples** — No scope misalignment relative to this run's changes.
`test_finalize_summary_tester_guard.sh` exercises `lib/finalize_summary.sh`
(unchanged this run). `test_find_next_milestone_dag.sh` and
`test_find_source_files_depth.sh` exercise unrelated subsystems; their referenced
functions and files have not been touched.
