## Test Audit Report

### Audit Summary
Tests audited: 1 file, 3 test scenarios (sidecar startup/kill, pidfile cleanup, watchdog bonus)
Verdict: PASS

Implementation cross-referenced: `lib/tui.sh` (`tui_stop`), `tools/tui.py` (watchdog + escape hatch), `tools/tui_render_timings.py` (label wrap).

---

### Findings

#### EXERCISE: Process-alive check accepts watchdog death as a passing outcome
- File: tests/test_tui_orphan_lifecycle_integration.sh:156-164
- Issue: The loop polls `_proc_alive` for up to 5 seconds (10 × 0.5 s) and passes on any cause
  of death, explicitly acknowledging this with the message "Sidecar was killed by tui_stop (or
  watchdog fired)". With `--watchdog-secs 2`, the double-timeout escape hatch fires at 2 × 2 = 4 s
  of staleness — squarely inside the test's 5-second wait window. If `tui_stop`'s pidfile fallback
  were completely broken (e.g., the pre-fix early-return guard restored), the watchdog would kill
  the process by iteration ~8, and this block would still emit a PASS. The process-alive check
  therefore cannot independently certify that Fix #1 (tui_stop pidfile fallback) is working.
  The pidfile-removal check at line 175 IS a clean discriminator: if `tui_stop` early-returns it
  neither kills the process nor removes the pidfile, so the test fails there regardless. The
  process-alive PASS block is redundant and its attribution message is misleading.
- Severity: LOW
- Action: Raise `--watchdog-secs` to 60 in the first test scenario (lines 102-108) so the watchdog
  cannot fire during the 5-second polling window. This makes the process-alive check cleanly
  attribute death to `tui_stop` without ambiguity. Keep `--watchdog-secs 1` only in the second
  (watchdog-specific) scenario at line 196. The pidfile check at line 175 is authoritative and
  should be kept as-is regardless.

#### COVERAGE: Watchdog escape hatch bonus test uses a no-op instead of fail
- File: tests/test_tui_orphan_lifecycle_integration.sh:220-223
- Issue: The bonus watchdog scenario (lines 187-224) calls `warn` when `WATCHDOG_FIRED` is false:
  ```bash
  if [[ "$WATCHDOG_FIRED" == "false" ]]; then
      warn "Watchdog test: sidecar still alive after 5 seconds (may be slow system)"
      kill -9 "$WATCHDOG_PID" 2>/dev/null || true
  fi
  ```
  `warn` is stubbed to a no-op (`:`) at line 22 — it does not increment `FAIL` and does not affect
  the exit code. Fix #2 (the `2 × watchdog_secs` escape hatch in `tools/tui.py:206`) therefore has
  no hard assertion in this file. If the escape hatch were reverted, the integration test exits 0.
  Fix #2 is covered by hard assertions only in `tools/tests/test_tui.py` (coder-authored unit
  tests; not in this audit's scope). The integration file's watchdog scenario is effectively
  advisory only.
- Severity: MEDIUM
- Action: Replace `warn "Watchdog test: ..."` with
  `fail "Watchdog escape hatch" "sidecar PID=$WATCHDOG_PID still alive after 5 s"` so the
  bonus scenario produces a definitive failure when the implementation regresses. If latency on
  loaded CI is a concern, extend the poll budget (e.g., 30 × 0.25 s = 7.5 s) rather than silently
  tolerating a non-fire. The "may be slow system" escape belongs in a skip guard, not a silent
  no-op.

---

### No findings in remaining categories

**INTEGRITY:** No always-passing assertions. All pass/fail calls verify outputs from real function
calls with meaningful inputs. The hard-coded values used in fixture data (`"running"`, `0`,
`"testing"`) are inputs fed into the implementation, not expected outputs — they are structurally
honest.

**SCOPE:** The test correctly targets `lib/tui.sh::tui_stop` and `tools/tui.py`. It does not
exercise `tools/tui_render_timings.py` (the label-wrap polish fix), which is appropriate — that
fix is a rendering change with no tui_stop/watchdog overlap.

**WEAKENING:** `tests/test_tui_orphan_lifecycle_integration.sh` is a new file; no existing
assertions were removed or broadened.

**NAMING:** Test messages clearly describe the scenario and expected outcome. The "or watchdog
fired" qualifier in the PASS message (line 158) accurately flags ambiguity but should be resolved
by the LOW fix above rather than left as permanent documentation of a known gap.

**ISOLATION:** The test creates a fresh `mktemp -d` directory, exports `PROJECT_DIR` and
`TEKHTON_SESSION_DIR` into it, and removes the tree on EXIT. It does not read `.tekhton/`,
`.claude/logs/`, or any live pipeline artifact. Isolation is clean.

**IMPLEMENTATION EXERCISE:** The test sources the real `lib/tui.sh`, spawns the real
`tools/tui.py`, and calls the real `tui_stop`. Mocking is limited to logging stubs (`log`,
`warn`, `error`, etc.) that are irrelevant to the fix paths under test. Implementation exercise
is strong.
