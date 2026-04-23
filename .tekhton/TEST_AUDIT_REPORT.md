## Test Audit Report

### Audit Summary
Tests audited: 1 file, 11 test functions (12 pass-points — Test 1 has two assertions)
Verdict: PASS

### Findings

#### ISOLATION: _activate_tui() does not reset cycle/closed-lifecycle maps
- File: tests/test_tui_multipass_lifecycle.sh:44–62
- Issue: `_activate_tui()` reinitialises most TUI globals but leaves
  `_TUI_STAGE_CYCLE` and `_TUI_CLOSED_LIFECYCLE_IDS` untouched. Both are declared
  `declare -gA` in `lib/tui.sh` and accumulate across test functions within the
  same shell process. Test 8 works around this by explicitly zeroing them
  (`_TUI_STAGE_CYCLE=(); _TUI_CLOSED_LIFECYCLE_IDS=()`) before its assertions,
  but Tests 7, 10, and 11 call `tui_stage_begin` without that reset. Currently
  not causing failures because those tests do not assert specific lifecycle-ID
  values; however, if a new test is added that relies on a known cycle baseline
  it will silently inherit counts from prior tests.
- Severity: MEDIUM
- Action: Add `_TUI_STAGE_CYCLE=(); _TUI_CLOSED_LIFECYCLE_IDS=()` to
  `_activate_tui()` so every test starts from a clean associative-array state.
  The explicit resets in Test 8 can be kept or removed once _activate_tui
  handles them — either is acceptable.

#### COVERAGE: Test 7 omits several reset-field assertions
- File: tests/test_tui_multipass_lifecycle.sh:208–217
- Issue: `tui_reset_for_next_milestone()` resets twelve fields in
  `lib/tui_ops.sh:165–182`. Test 7's compound condition verifies eight of them
  (`_TUI_STAGES_COMPLETE`, `_TUI_RECENT_EVENTS`, `_TUI_ACTIVE`, `_TUI_STAGE_ORDER`,
  `_TUI_CURRENT_STAGE_LABEL`, `_TUI_CURRENT_STAGE_NUM`, `_TUI_AGENT_STATUS`,
  `_TUI_AGENT_TURNS_USED`) but omits `_TUI_AGENT_TURNS_MAX`,
  `_TUI_AGENT_ELAPSED_SECS`, `_TUI_STAGE_START_TS`, `_TUI_CURRENT_LIFECYCLE_ID`,
  and `_TUI_CURRENT_STAGE_TOTAL`. A regression where one of those fields is
  accidentally preserved would pass Test 7 undetected.
- Severity: LOW
- Action: Extend the Test 7 condition to include the missing fields, or add a
  targeted Test 12 that sets them to non-zero/non-empty sentinel values before
  the reset and asserts they are zeroed afterward.

#### NAMING: File banner describes only the M111 regression scope
- File: tests/test_tui_multipass_lifecycle.sh:1–17
- Issue: The block comment describes the M111 sidecar-lifecycle regression
  exclusively. Tests 7–11 cover a different concern — the M122-125 auto-advance
  per-milestone TUI state-leak and the `tui_reset_for_next_milestone` contract —
  which is not mentioned in the banner. Future readers may not realise the file
  covers both areas.
- Severity: LOW
- Action: Append a second banner block (or extend the existing one) describing
  the M122-125 scope: "Tests 7–11 cover per-milestone TUI state isolation
  (tui_reset_for_next_milestone) added for the auto-advance state-leak fix."

### Additional Observations (no action required)

**STALE-SYM flags are all false positives.** Every flagged symbol
(`awk`, `break`, `cd`, `dirname`, `echo`, `eval`, `exit`, `mkdir`, `mktemp`,
`pwd`, `set`, `source`, `trap`, `:`) is a bash builtin or POSIX utility. The
shell symbol scanner has no model of builtins. Ignore.

**Assertion honesty: PASS.** All assertions are derived from real function
calls. `_hook_tui_complete` is awk-extracted from `lib/finalize_dashboard_hooks.sh`
at runtime (not hand-stubbed). The hook intentionally skips `out_complete`, so
`_TUI_ACTIVE` stays `true` and `_TUI_COMPLETE` stays `false` — both confirmed in
the implementation (finalize_dashboard_hooks.sh:150–162). The reset assertions in
Tests 7–9 trace directly to `tui_reset_for_next_milestone()` in
`lib/tui_ops.sh:165–182`. The cycle-advance math in Test 8 (`coder#1` → reset →
`coder#2`) is driven by `_tui_alloc_lifecycle_id()` at `lib/tui_ops.sh:188–195`.
No hard-coded magic values unrelated to implementation logic were found.

**Test isolation: PASS.** All tests use `TMPDIR=$(mktemp -d)` with an EXIT trap.
Status files are written under `$TMPDIR`. No mutable project files
(`.tekhton/CODER_SUMMARY.md`, pipeline logs, `pipeline.conf`, run artifacts,
`.claude/logs/`) are read or depended upon for pass/fail outcome.

**Weakening check: PASS.** Tests 1–6 are pre-existing. Their structure,
assertion counts, and expected values are unchanged. No weakening detected.

**Test exercise: PASS.** Tests source `lib/tui.sh` which transitively sources
`lib/tui_ops.sh`, `lib/tui_ops_substage.sh`, `lib/tui_helpers.sh`, and
`lib/output_format.sh`. All calls go to production code. No dependency is mocked
beyond suppressing the Python sidecar spawn (by not calling `tui_start`) and
setting `_TUI_STATUS_FILE` to a temp-dir path so `_tui_write_status` has a
writable target.
