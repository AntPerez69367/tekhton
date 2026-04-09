# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-09 | "M69"] `crawler.sh:136` — Stale comment: "no head -500 truncation; `_truncate_section` handles display limits." `_truncate_section` was deleted in M69; comment should be updated.
- [ ] [2026-04-09 | "M69"] `tekhton.sh:779` — Source comment says "also sources … crawler_deps.sh" — that file doesn't exist; should read `crawler_emit.sh`.
- [ ] [2026-04-09 | "M69"] `index_view.sh:418-421` — Last-resort budget guard in `_view_render_tests` uses substring truncation (`output="${output:0:$budget}"`) instead of record selection, inconsistent with other section renderers. Works correctly but diverges from the stated design principle.
- [ ] [2026-04-09 | "M69"] `index_view.sh:451` — Sample file path built as `${index_dir}/samples/${stored}` without validating `$stored` for path traversal characters. Risk is minimal (manifest written by Tekhton itself).
- [ ] [2026-04-09 | "M69"] `index_view.sh:205-208` — Inventory field extraction uses sequential `sed` calls on `$line`; filenames with regex-special characters could produce garbled table output.

## Resolved
