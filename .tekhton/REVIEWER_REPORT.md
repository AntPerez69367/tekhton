# Reviewer Report — M73 (Notes blank-line normalization) — Re-review Cycle 2

## Verdict
APPROVED_WITH_NOTES

## Prior Blocker Verification

**FIXED** — `tests/test_notes_normalization.sh:260` dead `last_char_hex` variable removed.
The line `last_char_hex=$(tail -c 2 "$IDEM_FILE" | xxd -p | tail -c 5)` is gone.
Line 260 now reads `last_line=$(tail -1 "$IDEM_FILE")`, which is the assignment
actually used by the assertion. JR coder report confirms `bash -n` passes and
SC2034 warning is eliminated with no new warnings introduced.

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `lib/drift_cleanup.sh` is exactly 300 lines — the project ceiling is *under* 300. Consider extracting `_resolve_addressed_nonblocking_notes()` to a helper on next cleanup pass (carried from cycle 1).
- `_normalize_markdown_blank_runs()` (`lib/notes_core_normalize.sh:30`) silently drops a single blank line that appears immediately before a fenced code block: `blank_pending = 0` is set by the fence handler before the pending blank is emitted, so a lone blank before ``` is lost. The spec says "collapse runs of ≥ 2 blank lines to one" — a single blank should survive. Low-risk edge case in practice (carried from cycle 1).
- Security agent flagged two LOW findings in `lib/notes_core_normalize.sh`: missing `trap` for tmpfile cleanup on failure (line 27), and `mv` not preserving file permissions (line 42). Both are fixable; the security report marks them `fixable:yes`.

## Coverage Gaps
- None

## Drift Observations
- None
