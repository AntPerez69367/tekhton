## Test Audit Report

### Audit Summary
Tests audited: 3 files, 74 test functions (47 shell assertions + 27 Python test functions)
Verdict: PASS

### Findings

None

---

### Per-File Notes

#### tests/test_pipeline_order.sh (Phase 12 — 7 new assertions)

All seven Phase 12 assertions for `get_display_stage_order()` exercise the real
function directly after setting environment variables. Expected values were
cross-checked against `lib/pipeline_order.sh`:

- `PIPELINE_ORDER_STANDARD="scout coder security review test_verify"` + intake
  prepend + `test_verify`→`tester` mapping produces `"intake scout coder security
  review tester"` (12.1 ✓)
- `INTAKE_AGENT_ENABLED=false` drops the intake prepend (12.2 ✓)
- `DOCS_AGENT_ENABLED=true` triggers the `${stages/coder security/coder docs security}`
  substitution inside `get_pipeline_order()` and `get_display_stage_order()` passes
  `docs` through its filter unchanged (12.3 ✓)
- `PIPELINE_ORDER=test_first` maps `test_write`→`tester-write` in the display
  layer (12.4 ✓)
- `SKIP_SECURITY=true` and `SECURITY_AGENT_ENABLED=false` both trigger the
  `continue` branch in `get_display_stage_order()` (12.5, 12.6 ✓)
- `SKIP_DOCS=true` suppresses `docs` even when `DOCS_AGENT_ENABLED=true` because
  `get_display_stage_order()` filters `docs` after `get_pipeline_order()` has
  already inserted it (12.7 ✓)

Isolation: env vars are set and unset inline; no mutable project files read.
STALE-SYM flags (`cd`, `echo`, `source`, `set`, etc.) are standard bash builtins —
known false positives for the shell orphan detector.

#### tests/test_tui_set_context.sh (3 new M100 assertions, lines 264–297)

All three assertions exercise `_tui_stage_order_json()` in `lib/tui_helpers.sh`
after sourcing `lib/tui.sh`. Cross-checked against the implementation:

- Fallback path: `declare -p _TUI_STAGE_ORDER` succeeds but array has zero
  non-empty entries → function checks `_OUT_CTX[stage_order]` → splits the
  space-separated string into `src[]` → emits JSON array.
  Assertion `'["intake","scout","coder","review","tester"]'` is correct (✓)
- Precedence: `_TUI_STAGE_ORDER=(scout coder tester)` with a longer
  `_OUT_CTX[stage_order]` → `src` is populated from the array branch and the
  fallback branch is skipped. Assertion `'["scout","coder","tester"]'` is
  correct (✓)
- All-empty: both sources empty → loop never executes → `[]` is correct (✓)

Isolation: uses `mktemp -d` with `trap 'rm -rf' EXIT`. No mutable project files.
STALE-SYM flags are bash builtins and standard utilities.

#### tools/tests/test_tui.py (2 replacement M100 tests + existing suite)

**Weakening flag — justified removal (not a real weakening):**
`test_build_stage_pills_default_order_fallback` was removed because it asserted
six pending pills from the hardcoded fallback list `["intake","scout","coder",
"security","review","tester"]` that was deliberately deleted from
`_build_stage_pills` in `tui_render.py`. The TESTER_REPORT documents the
rationale. The two replacement tests cover the new correct behavior:

- `test_build_stage_pills_empty_order_no_stage_total` (line 341): no `stage_order`
  and no `stage_total` → `order=[]`, loop does not execute, `Text()` stays empty
  → `str(pills) == ""`. Cross-checked: `_build_stage_pills` returns an unmodified
  empty `Text()` when both `stage_order` and `stage_total` are absent (✓)
- `test_build_stage_pills_empty_order_uses_stage_total_fallback` (line 354):
  `stage_total=4` → implementation generates `["stage-1","stage-2","stage-3",
  "stage-4"]` → 4× `○` pending pills. Assertions `count("\u25cb") == 4`,
  `"stage-1" in text`, `"stage-4" in text` verified against implementation (✓)

The replaced test exercised a code path that no longer exists; the two replacement
tests cover both remaining code paths exhaustively. Coverage is not reduced.

STALE-SYM flags (`Console`, `Panel`, `pytest`, `json`, `sys`, `tui`, `tui_render`,
etc.) are Python stdlib and third-party imports — known false positives for the
shell-based orphan detector which does not parse Python.
