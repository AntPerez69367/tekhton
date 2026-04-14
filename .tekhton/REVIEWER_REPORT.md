# Reviewer Report — M82: Milestone Progress CLI & Run-Boundary Guidance (Cycle 2)

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `_render_progress_bar` (milestone_progress_helpers.sh:176–180) still forks a subshell for every bar character — 40+ forks per render. Correct, low priority given display-only context; a `printf -v` approach would be faster.
- `test_milestone_progress_display.sh` uses `grep -qP '[\xe2]'` to detect UTF-8 bytes. `grep -P` requires PCRE support which is not guaranteed on all platforms; if absent the test trivially passes without checking anything. A `printf | xxd` or POSIX-compatible pattern is safer.
- `lib/common.sh` (334 lines) and `lib/diagnose_output.sh` (343 lines) remain over the 300-line ceiling — pre-existing, acknowledged by coder.

## Coverage Gaps
- None

## Drift Observations
- `lib/common.sh` has no `set -euo pipefail` (long-standing omission), while `finalize_display.sh`, `diagnose_output.sh`, `milestone_progress.sh`, and `milestone_progress_helpers.sh` all do. The codebase has split conventions for sourced lib files. A cleanup pass to align all lib files would resolve the inconsistency.

---

## Blocker Verification (prior cycle)

**Blocker 1 — `set -euo pipefail` missing from both new lib files**
- `lib/milestone_progress.sh:2` — `set -euo pipefail` present. **FIXED.**
- `lib/milestone_progress_helpers.sh:2` — `set -euo pipefail` present. **FIXED.**

**Blocker 2 — `_diagnose_recovery_command` double-quote injection into displayed CLI string**
- `lib/milestone_progress.sh:161` — `milestone="${milestone//\"/\\\"}"` applied before interpolation. **FIXED.**
- `lib/milestone_progress.sh:166` — `task="${task//\"/\\\"}"` applied before interpolation. **FIXED.**
- Both escaping operations are inside their respective `if` guards and applied before the variable is embedded into `cmd`.
