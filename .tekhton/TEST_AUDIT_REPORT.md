## Test Audit Report

### Audit Summary
Tests audited: 4 files, 73 test functions/assertions
Verdict: PASS

### Findings

#### ISOLATION: _activate_m110 missing substage global resets
- File: tests/test_tui_stage_wiring.sh:253
- Issue: `_activate_m110()` resets `_TUI_STAGE_CYCLE`, `_TUI_CURRENT_LIFECYCLE_ID`, and `_TUI_CLOSED_LIFECYCLE_IDS` but omits `_TUI_CURRENT_SUBSTAGE_LABEL` and `_TUI_CURRENT_SUBSTAGE_START_TS`. M113 added those globals and wired `_tui_autoclose_substage_if_open` into `tui_stage_end` — so every M110 test that calls `tui_stage_end` now implicitly invokes that helper, which reads `_TUI_CURRENT_SUBSTAGE_LABEL`. The tests pass today only because `lib/tui.sh` initialises both variables at source time (`""` and `0`) and no M110 test calls `tui_substage_begin`, so the autoclose guard `[[ -z "$sublabel" ]] && return 0` fires immediately and is harmless. Any future test in this file that opens a substage and forgets to close it before calling `_activate_m110` would leave dirty globals that silently corrupt subsequent M110 assertions.
- Severity: LOW
- Action: Add `_TUI_CURRENT_SUBSTAGE_LABEL=""` and `_TUI_CURRENT_SUBSTAGE_START_TS=0` to `_activate_m110()` alongside the existing `_TUI_CURRENT_LIFECYCLE_ID=""` reset (line 273). Two lines, no logic change.

#### COVERAGE: Substantial overlap between test_pipeline_order_policy.sh and test_pipeline_order_m110.sh
- File: tests/test_pipeline_order_policy.sh, tests/test_pipeline_order_m110.sh
- Issue: Both files test the same three functions (`get_stage_metrics_key`, `get_stage_policy`, `get_run_stage_plan`) against nearly identical input sets. `test_pipeline_order_m110.sh` is a strict superset — it adds boundary-condition cases for drift thresholds and the fix-drift flag combination that the policy file lacks. The tester modified both files without consolidating, resulting in 40+ redundant assertions that add run time without adding coverage.
- Severity: LOW
- Action: No immediate action required; the overlap does not weaken either suite. If the team runs a future coverage cleanup pass, `test_pipeline_order_policy.sh` is the candidate for retirement and its unique cases (`get_stage_array_key`, empty-input passthrough) should be merged into `test_pipeline_order_m110.sh` first.

---

### Per-File Detail

**tests/test_tui_substage_api.sh** (NEW — created by coder; M113-9 and M113-10 added by tester)

- Assertion honesty: All assertions derive from actual `tui_substage_begin`/`tui_substage_end`/`tui_stage_end` calls. JSON field checks (M113-1c/1d, M113-8a/8b) use Python reading the real status file written by `_tui_write_status` via `_tui_json_build_status` in `lib/tui_helpers.sh:209-210`. No hard-coded magic values unrelated to implementation logic.
- Edge case coverage: Eight coder-authored sections cover: begin/set, parent-state preservation, end/clear, full begin/end cycle, auto-close-and-warn, V2=false no-op (begin, end, and autoclose), external readability, and idle JSON keys. The tester-added M113-9 covers the empty-label guard (`[[ -z "$label" ]] && return 0` in `tui_ops_substage.sh:31`); M113-10 covers the inactive-TUI guard (`[[ "${_TUI_ACTIVE:-false}" == "true" ]] || return 0`). Both are real guards present in the implementation.
- Implementation exercise: `lib/tui.sh` sourced directly, which sources `lib/tui_ops_substage.sh` (line 25 of tui.sh). All three new functions in the implementation file are called. No mocking of production code.
- Test weakening: No pre-existing tests modified — only M113-9 and M113-10 were added by the tester.
- Naming: Pass names encode scenario and expected outcome throughout (e.g., "M113-5b: exactly one auto-close warn event emitted", "M113-6a: tui_substage_begin no-op under V2=false").
- Scope alignment: All tested functions (`tui_substage_begin`, `tui_substage_end`, `_tui_autoclose_substage_if_open`) exist in `lib/tui_ops_substage.sh`. All tested globals (`_TUI_CURRENT_SUBSTAGE_LABEL`, `_TUI_CURRENT_SUBSTAGE_START_TS`) are declared in `lib/tui.sh:72-73`.
- Isolation: Creates its own `$TMPDIR` with `trap 'rm -rf "$TMPDIR"' EXIT`. Status file is written to `$TMPDIR/status.json`. No mutable project state is read.
- Result: No findings.

**tests/test_tui_stage_wiring.sh** (modified — M110 regression guard)

- Assertion honesty: All assertions test real TUI state transitions. JSON checks use Python on a real status file.
- Edge case coverage: Covers lifecycle monotonicity (M110-1), stale-id drop (M110-3), transition atomicity (M110-5/6), event-type field in ring buffer (M110-9/10/11), multi-cycle rework (M110-12), and the intake-at-end regression guard (M110-13).
- Implementation exercise: Sources real `lib/tui.sh` and `lib/pipeline_order.sh`. No mocking.
- Naming: Descriptive (e.g., "M110-3a: update with closed lifecycle id is dropped (turns_used stays 0)").
- Scope alignment: All functions referenced exist in the current implementation.
- Isolation: `_activate()` and `_activate_m110()` reset in-memory state; status file is in `$TMPDIR`. LOW finding on missing substage resets in `_activate_m110` — see above.

**tests/test_pipeline_order_policy.sh** (modified — regression guard)

- Assertion honesty: Expected values (`"pre|yes|yes|yes|-"`, stage plans) are derived from the §2 policy table in `lib/pipeline_order_policy.sh`. Verified by cross-reading the implementation.
- Edge case coverage: Covers all alias pairs, idempotent canonical keys, unknown-stage fallback, empty-input, and all `get_run_stage_plan` flag combinations. No boundary arithmetic to test here, so coverage is appropriate.
- Implementation exercise: Calls production functions directly with no stubs.
- Isolation: `TMPDIR=$(mktemp -d)` with cleanup trap. No mutable project state read.
- Result: Overlap note only (LOW, see above). No other findings.

**tests/test_pipeline_order_m110.sh** (modified — regression guard)

- Assertion honesty: `assert_eq` expected values match the implementation's policy records and stage-plan output strings. Verified against `lib/pipeline_order_policy.sh` and `lib/pipeline_order.sh`.
- Edge case coverage: Adds drift-threshold boundary conditions (equal, above, below for both count and runs-since-audit thresholds), the FORCE_AUDIT+SKIP_SECURITY combination (Phase 18), and the no-preflight+no-intake+FORCE_AUDIT combination (Phase 18.2) that `test_pipeline_order_policy.sh` does not cover.
- Implementation exercise: Calls `get_stage_metrics_key`, `get_stage_policy`, `get_run_stage_plan` directly from `lib/pipeline_order.sh`. Sources `lib/common.sh` for logging stubs.
- Isolation: `_reset_env()` unsets all relevant env vars between test phases. No mutable project state read.
- Result: Overlap note only (LOW, see above). No other findings.
