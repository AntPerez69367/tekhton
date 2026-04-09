# Reviewer Report — M67: Structured Project Index Data Layer

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `crawler_emit.sh` is 521 lines, over the 300-line soft ceiling. All 7 emitters landed in one file instead of the spec's per-source-file split (e.g., `_emit_dependencies_json` was specified for `crawler_deps.sh`). Functionally correct; candidate for `--cleanup` pass once M69 lands.
- Comment at `tekhton.sh:777` is stale: it reads "also sources … crawler_deps.sh (via crawler_content.sh)" but does not mention the newly added `crawler_emit.sh`. Low-risk but will mislead future readers.
- `tmp_m=$(mktemp) tmp_d=$(mktemp)` on one line in `_emit_dependencies_json` (`crawler_emit.sh:113`). Valid bash, but the compound single-line assignment is uncommon in the codebase and masks intent. Prefer two separate lines.
- `_emit_sampled_files` accumulates manifest JSON entries via string concatenation (`manifest_entries+=...`). For the small number of sample files this is harmless, but it contrasts with the O(n) inventory fix that was the point of the milestone.

## Coverage Gaps
- `tests/test_structured_index.sh` does not exercise the incremental rescan path: no test verifies that `_record_scan_metadata` reads `file_count`/`total_lines` from `inventory.jsonl` instead of re-running `wc -l` per file (spec §12 fix).
- No test for the `rescan_project` full-crawl fallback after M67 structured files exist (ensures `_record_scan_metadata` updates `meta.json` correctly on subsequent rescans).

## Drift Observations
- `crawler_emit.sh:300-366` (`_emit_tests_json`) and `crawler_inventory.sh:183-258` (`_crawl_test_structure`) duplicate ~60 lines of framework/coverage detection logic. Both are needed for now (one emits JSON, one emits markdown for the legacy bridge), but the duplication will compound in M69 when the markdown producer is retired.
- `_generate_legacy_index` (`crawler_emit.sh:476-520`) calls `_crawl_directory_tree` a second time, even though `_emit_tree_txt` already ran it and wrote the result to `tree.txt`. The legacy bridge could read `tree.txt` instead, saving a redundant traversal. Not worth fixing until M69 removes the bridge.
