# Reviewer Report

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `tools/tests/test_tui.py` is 1153 lines, well above the 300-line production ceiling. The coder's justification (pre-existing at 1045 lines, test conventions differ from production code) is sound — test files in `tools/tests/` already exceed 300 lines (`test_tui_render_timings.py` is 517 lines). No action required, but worth tracking if the file grows further.
- The two Python watchdog tests (`test_double_timeout_fires_on_running_status_after_2x_staleness`, `test_double_timeout_does_not_fire_before_2x_threshold`) reproduce the conditional logic inline rather than exercising `main()` directly. This is a pragmatic trade-off for a bugfix test (mocking the full Live loop is expensive), but the tests would not catch a typo in the actual `main()` branch condition if the test author's transcription were wrong. Acceptable as-is; an integration test or a helper function extracted from `main()` would make this more robust.
- `tui_complete` retains `[[ "$_TUI_ACTIVE" == "true" ]] || return 0` while `tui_stop` no longer has that guard. The asymmetry is intentional and correct (complete = happy-path only, stop = unconditional teardown from EXIT trap), but a short inline comment explaining why complete keeps the guard — e.g. `# Only runs on happy-path; EXIT trap calls tui_stop directly` — would prevent future confusion.

## Coverage Gaps
- No integration-level test that exercises the full orphan lifecycle: spawn a real `tools/tui.py` sidecar, simulate a failure exit while `_TUI_ACTIVE` is false, and verify the PID is dead and the pidfile is removed. The four bash unit tests in `test_tui_stop_orphan_recovery.sh` cover the `tui_stop` shell logic thoroughly, but a real-sidecar smoke test would catch regressions in Python startup/shutdown. Optional for a bugfix; acceptable to leave as a gap.

## ACP Verdicts
*(no `## Architecture Change Proposals` section in CODER_SUMMARY.md)*

## Drift Observations
- `tools/tui.py:193–207` — the watchdog block now has two independent `if … break` branches that both share the `staleness` computation from the same `time.monotonic()` snapshot. This is correct and efficient. If a third watchdog variant is ever needed, extracting the block into a `_watchdog_should_fire(status, staleness, watchdog_secs)` helper would prevent the staleness variable from being duplicated across branches.
- `lib/tui.sh::tui_complete (line 233)` vs `tui_stop` — the now-divergent guard semantics (complete = active-only, stop = unconditional) are a consequence of fixing the orphan bug without adding an explicit API contract note. See non-blocking note above.
