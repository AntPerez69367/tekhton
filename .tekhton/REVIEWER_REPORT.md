# Reviewer Report — M98 TUI Redesign

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `lib/tui.sh:162` — `tui_complete()` poll loop calls `$(date +%s)` in every 100 ms tick, yielding up to ~1200 subprocess forks over the 120 s default hold. A counter-based approximation (`(( ticks++ ))` + compare once per second) would eliminate the per-tick fork cost. Low priority since it runs once at end-of-run only.
- `tools/tests/test_tui.py:110` — `Console(file=open("/dev/null", "w"), ...)` leaks a file descriptor; use a variable + explicit close, or a `with` block, to be tidy.
- `lib/tui.sh:61` — `_tui_should_activate` gates on `[[ ! -t 1 ]]` (stdout TTY), but the sidecar writes directly to `/dev/tty` and could work even when stdout is redirected (e.g. `tekhton.sh | tee log`). Current check is conservative; no behaviour change required.

## Coverage Gaps
- `tui_set_context` in `lib/tui.sh` and `_tui_stage_order_json` in `lib/tui_helpers.sh` have no direct shell unit tests. JSON output is exercised indirectly through the status-file read path; a dedicated shell test for the `stage_order` JSON array would close this gap.
- `_build_stage_pills` and `_build_context` are exercised only indirectly through `test_build_header_bar_*`; direct unit tests for pill state transitions (pending/running/complete/fail) would be useful.

## Drift Observations
- None

## ACP Verdicts
(None declared in CODER_SUMMARY.md — section omitted per reviewer instructions.)
