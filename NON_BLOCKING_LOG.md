# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-09 | "M67"] `crawler_emit.sh` is 521 lines, over the 300-line soft ceiling. All 7 emitters landed in one file instead of the spec's per-source-file split (e.g., `_emit_dependencies_json` was specified for `crawler_deps.sh`). Functionally correct; candidate for `--cleanup` pass once M69 lands.
- [ ] [2026-04-09 | "M67"] Comment at `tekhton.sh:777` is stale: it reads "also sources … crawler_deps.sh (via crawler_content.sh)" but does not mention the newly added `crawler_emit.sh`. Low-risk but will mislead future readers.
- [ ] [2026-04-09 | "M67"] `tmp_m=$(mktemp) tmp_d=$(mktemp)` on one line in `_emit_dependencies_json` (`crawler_emit.sh:113`). Valid bash, but the compound single-line assignment is uncommon in the codebase and masks intent. Prefer two separate lines.
- [ ] [2026-04-09 | "M67"] `_emit_sampled_files` accumulates manifest JSON entries via string concatenation (`manifest_entries+=...`). For the small number of sample files this is harmless, but it contrasts with the O(n) inventory fix that was the point of the milestone.

## Resolved
