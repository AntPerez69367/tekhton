# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in ${REVIEWER_REPORT_FILE}.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [x] [2026-04-12 | "M73"] `lib/drift_cleanup.sh` is exactly 300 lines — the project ceiling is *under* 300. Consider extracting `_resolve_addressed_nonblocking_notes()` to a helper on next cleanup pass (carried from cycle 1).
- [ ] [2026-04-12 | "M73"] `_normalize_markdown_blank_runs()` (`lib/notes_core_normalize.sh:30`) silently drops a single blank line that appears immediately before a fenced code block: `blank_pending = 0` is set by the fence handler before the pending blank is emitted, so a lone blank before ``` is lost. The spec says "collapse runs of ≥ 2 blank lines to one" — a single blank should survive. Low-risk edge case in practice (carried from cycle 1).
- [x] [2026-04-12 | "M73"] Security agent flagged two LOW findings in `lib/notes_core_normalize.sh`: missing `trap` for tmpfile cleanup on failure (line 27), and `mv` not preserving file permissions (line 42). Both are fixable; the security report marks them `fixable:yes`.
<!-- Items added here by the pipeline. Mark [x] when addressed. -->

## Resolved
