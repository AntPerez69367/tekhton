# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [x] [2026-04-19 | "M101"] `lib/init_helpers_display.sh:34,43,53` still uses `echo -e` with ANSI-containing local variables (`${icon}`, `${_g}`, `${_nc}`) rather than the new structured formatters. `NO_COLOR` is handled correctly via `_out_color` calls at the top of the function, but the pattern is inconsistent with the migration goal and bypasses the formatter's TUI routing. The lint test misses it because `test_output_lint.sh` only matches `${BOLD|RED|GREEN|YELLOW|CYAN|NC}` literals, not local-variable aliases. Security agent already flagged these lines as LOW/fixable (`echo -e` on filesystem-derived data); fix by switching the three `echo -e` lines to `printf '%s '` calls with the pre-computed `${_g}`/`${_nc}` values.
- [x] [2026-04-19 | "M101"] `test_output_lint.sh` regex gap: any new file that aliases `BOLD`/`RED` etc. to a local variable before calling `echo -e` will bypass the lint guard. Consider adding a broader pattern or a `printf '%b'` check alongside the current pattern to harden the enforcement for M103+.
- [ ] [2026-04-19 | "M101"] The `_out_color` implementation emits `printf ''` (no-op printf) in the NO_COLOR branch. Functionally correct (subshell capture returns ""), but `printf ''` is a more opaque idiom than a plain `return 0` or a `printf '%s' ""`. Not worth changing, but noting for future readability.

## Resolved
