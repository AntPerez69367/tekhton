# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-18 | "M98"] `lib/tui.sh:162` — `tui_complete()` poll loop calls `$(date +%s)` in every 100 ms tick, yielding up to ~1200 subprocess forks over the 120 s default hold. A counter-based approximation (`(( ticks++ ))` + compare once per second) would eliminate the per-tick fork cost. Low priority since it runs once at end-of-run only.
- [ ] [2026-04-18 | "M98"] `tools/tests/test_tui.py:110` — `Console(file=open("/dev/null", "w"), ...)` leaks a file descriptor; use a variable + explicit close, or a `with` block, to be tidy.
- [ ] [2026-04-18 | "M98"] `lib/tui.sh:61` — `_tui_should_activate` gates on `[[ ! -t 1 ]]` (stdout TTY), but the sidecar writes directly to `/dev/tty` and could work even when stdout is redirected (e.g. `tekhton.sh | tee log`). Current check is conservative; no behaviour change required.

## Resolved
