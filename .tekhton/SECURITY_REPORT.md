## Summary
M73 introduces a single new bash helper `_normalize_markdown_blank_runs()` in `lib/notes_core_normalize.sh` and integrates it at five call sites across `lib/notes.sh`, `lib/drift_cleanup.sh`, and `lib/notes_cleanup.sh`. The change is purely text-processing (markdown blank-line normalization via `awk`) with no network I/O, authentication logic, cryptography, or user-supplied input. All variables are quoted and the `awk` program contains no external calls or injection vectors. Two low-severity hardening gaps were found in the temp-file handling pattern.

## Findings
- [LOW] [category:A04] [lib/notes_core_normalize.sh:27-42] fixable:yes — No `trap` is set to remove `$tmpfile` on failure. If `awk` exits non-zero (e.g. disk full, SIGINT), the partial temp file containing notes content is left in `TEKHTON_SESSION_DIR` or `/tmp` and never cleaned up. Fix: add `trap 'rm -f "$tmpfile"' EXIT` immediately after the `mktemp` call and remove it on success.
- [LOW] [category:A04] [lib/notes_core_normalize.sh:42] fixable:yes — `mv "$tmpfile" "$file"` replaces the original file without preserving its permissions. `mktemp` creates files with mode 0600; if the target file had wider permissions (e.g. 0644), the replacement silently tightens them. Fix: capture permissions with `stat` before writing and restore with `chmod` after `mv`, or use `install -m` instead.

## Verdict
CLEAN
