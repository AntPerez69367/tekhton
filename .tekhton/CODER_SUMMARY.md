# Coder Summary
## Status: COMPLETE

## What Was Implemented
Addressed all 3 open non-blocking notes in `.tekhton/NON_BLOCKING_LOG.md` and moved them to the Resolved section.

1. **`lib/tui.sh:162` — `tui_complete()` per-tick `date +%s` forks.** Replaced the `(( $(date +%s) >= deadline ))` check in the 100 ms poll loop with a counter-based approximation (`ticks`/`max_ticks = hold_timeout * 10`). Eliminates up to ~1200 `date` subprocess forks over the default 120 s hold. Accuracy is unchanged in practice because `sleep 0.1` already dominates the tick period.

2. **`tools/tests/test_tui.py:110` — `Console(file=open("/dev/null", "w"), ...)` FD leak.** Wrapped the open in a `with` block so the file descriptor is closed deterministically after `console.print(layout)` returns.

3. **`lib/tui.sh:61` — `_tui_should_activate` TTY gate.** The reviewer note explicitly said "no behaviour change required" — the conservative `[[ ! -t 1 ]]` check is intentional so that `tekhton.sh | tee log` produces clean log output rather than leaking escape sequences through `/dev/tty`. Added a short comment at the gate capturing that rationale so the intent is clear to future readers.

## Root Cause (bugs only)
N/A — all three items were polish / tech-debt non-blocking notes, not bugs.

## Files Modified
- `lib/tui.sh` — counter-based `tui_complete()` poll; added rationale comment on TTY gate
- `tools/tests/test_tui.py` — FD leak fix (`with open(...) as devnull`)
- `.tekhton/NON_BLOCKING_LOG.md` — moved the 3 items from Open to Resolved

## Human Notes Status
No active human notes for this task — the task operated on `NON_BLOCKING_LOG.md` items, which are a separate channel from `HUMAN_NOTES.md`.

## Docs Updated
None — no public-surface changes in this task. All changes were internal: a fork-cost optimisation inside `tui_complete()`, a test-file resource cleanup, and a rationale comment.

## Verification
- `shellcheck -x lib/tui.sh` — clean
- `bash tests/test_tui_fallback.sh` + `test_tui_active_path.sh` + `test_tui_no_dead_weight.sh` + `test_tui_set_context.sh` — 9 + 23 + 5 + 21 = 58 passed, 0 failed
- `python -m pytest tools/tests/test_tui.py` — 45 passed
- Full `bash tests/run_tests.sh` — 376 shell passed, 16 failed; all 16 failures are pre-existing on the unmodified tree (verified via `git stash` + re-run of `test_context_accounting.sh`). None touch `lib/tui.sh` or `test_tui.py`.
