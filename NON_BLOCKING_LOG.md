# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-01 | "M49"] `build_intake_history_from_memory` uses `grep -oP` (Perl-mode regex) for field extraction at lines 281–285 of `lib/run_memory.sh`. GNU grep (Linux/WSL) supports this, but BSD grep (macOS) does not. The fallback `|| echo "unknown"` prevents errors — output degrades to "unknown" fields rather than crashing — so this is safe on the current platform. Flag for portability if macOS support is ever required.
- [ ] [2026-04-01 | "M49"] The header comment in `tests/test_finalize_run.sh` (line 6) still reads "12 hooks in deterministic sequence, plus M13+M17+M19 hooks". The actual count is now 20. The assertion on line 255 (`"1.1 exactly 20 hooks registered"`) is correct; only the descriptive comment is stale.
- [ ] [2026-04-01 | "Complete the blockers in the REVIEWER_REPORT.md then resume the pipeline run from .claude/PIPELINE_STATE.md"] `NON_BLOCKING_LOG.md` Resolved section is empty — the 3 resolved items were removed rather than moved; traceability of what was fixed is lost. Consider appending entries under `## Resolved` when closing notes.
- [ ] [2026-04-01 | "Address all 3 open non-blocking notes in NON_BLOCKING_LOG.md. Fix each item and note what you changed."] `NON_BLOCKING_LOG.md` Resolved section is empty — the 3 resolved items were removed rather than moved; traceability of what was fixed is lost. Consider appending entries under `## Resolved` when closing notes.

## Resolved
