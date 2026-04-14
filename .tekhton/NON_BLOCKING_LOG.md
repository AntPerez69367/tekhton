# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-13 | "M82"] `_render_progress_bar` (milestone_progress_helpers.sh:176–180) still forks a subshell for every bar character — 40+ forks per render. Correct, low priority given display-only context; a `printf -v` approach would be faster.
- [x] [2026-04-13 | "M82"] `test_milestone_progress_display.sh` uses `grep -qP '[�]'` to detect UTF-8 bytes. `grep -P` requires PCRE support which is not guaranteed on all platforms; if absent the test trivially passes without checking anything. A `printf | xxd` or POSIX-compatible pattern is safer.
- [x] [2026-04-13 | "M82"] `lib/common.sh` (334 lines) and `lib/diagnose_output.sh` (343 lines) remain over the 300-line ceiling — pre-existing, acknowledged by coder.

## Resolved
