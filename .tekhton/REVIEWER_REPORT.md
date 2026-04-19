# Reviewer Report — M101 Eliminate Direct ANSI Output

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `lib/init_helpers_display.sh:34,43,53` still uses `echo -e` with ANSI-containing local variables (`${icon}`, `${_g}`, `${_nc}`) rather than the new structured formatters. `NO_COLOR` is handled correctly via `_out_color` calls at the top of the function, but the pattern is inconsistent with the migration goal and bypasses the formatter's TUI routing. The lint test misses it because `test_output_lint.sh` only matches `${BOLD|RED|GREEN|YELLOW|CYAN|NC}` literals, not local-variable aliases. Security agent already flagged these lines as LOW/fixable (`echo -e` on filesystem-derived data); fix by switching the three `echo -e` lines to `printf '%s\n'` calls with the pre-computed `${_g}`/`${_nc}` values.
- `test_output_lint.sh` regex gap: any new file that aliases `BOLD`/`RED` etc. to a local variable before calling `echo -e` will bypass the lint guard. Consider adding a broader pattern or a `printf '%b'` check alongside the current pattern to harden the enforcement for M103+.
- The `_out_color` implementation emits `printf ''` (no-op printf) in the NO_COLOR branch. Functionally correct (subshell capture returns ""), but `printf ''` is a more opaque idiom than a plain `return 0` or a `printf '%s' ""`. Not worth changing, but noting for future readability.

## Coverage Gaps
- `out_msg()` TUI path (routes to `_tui_notify` + log file) has no unit test. All 68 assertions in `test_output_format.sh` force `_TUI_ACTIVE=false`, so the TUI-mode branch of every formatter is untested. Acceptable scope deferral — TUI integration tests are complex — but worth adding in M102 when TUI hold-screen consumption of `_OUT_CTX[action_items]` is exercised.

## ACP Verdicts
- None

## Drift Observations
- `lib/init_helpers_display.sh` was extracted from `init_helpers.sh` to keep `init_helpers.sh` under the 300-line ceiling, but the new file itself uses `echo -e` with aliased ANSI locals — a pattern that the lint test was designed to eliminate. The extraction preserved the old style rather than converting it, creating a latent gap in lint coverage.
- `test_output_lint.sh` checks `lib/` and `stages/` but excludes only `lib/common.sh`, `lib/output.sh`, `lib/output_format.sh`. If `lib/output_format.sh` itself ever exceeds 300 lines and is split, the exclusion list will need updating — a fragile coupling between file layout and lint configuration.
