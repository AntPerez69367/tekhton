# Reviewer Report — M49: Structured Run Memory

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `build_intake_history_from_memory` uses `grep -oP` (Perl-mode regex) for field extraction at lines 281–285 of `lib/run_memory.sh`. GNU grep (Linux/WSL) supports this, but BSD grep (macOS) does not. The fallback `|| echo "unknown"` prevents errors — output degrades to "unknown" fields rather than crashing — so this is safe on the current platform. Flag for portability if macOS support is ever required.
- The header comment in `tests/test_finalize_run.sh` (line 6) still reads "12 hooks in deterministic sequence, plus M13+M17+M19 hooks". The actual count is now 20. The assertion on line 255 (`"1.1 exactly 20 hooks registered"`) is correct; only the descriptive comment is stale.

## Coverage Gaps
- No test covers a task string containing special characters (e.g., `$`, backticks, single quotes) to verify JSONL integrity under adversarial input. The `_json_escape` function handles `\`, `"`, `\n`, `\r`, `\t`, but not `$` or `` ` `` which appear in task names that reference shell variables. This is a gap worth testing in a follow-up.

## Drift Observations
- `lib/run_memory.sh:281–285` — field extraction from JSONL uses `grep -oP` rather than a shared JSONL parsing helper. `lib/causality.sh` may already have related extraction patterns; if a future milestone adds more JSONL consumers, consolidating the parse logic into a helper would reduce duplication.

## ACP Verdicts
None present in CODER_SUMMARY.md.
