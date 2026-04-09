# Drift Log

## Metadata
- Last audit: 2026-04-08
- Runs since audit: 4

## Unresolved Observations
- [2026-04-09 | "M67"] `crawler_emit.sh:300-366` (`_emit_tests_json`) and `crawler_inventory.sh:183-258` (`_crawl_test_structure`) duplicate ~60 lines of framework/coverage detection logic. Both are needed for now (one emits JSON, one emits markdown for the legacy bridge), but the duplication will compound in M69 when the markdown producer is retired.
- [2026-04-09 | "M67"] `_generate_legacy_index` (`crawler_emit.sh:476-520`) calls `_crawl_directory_tree` a second time, even though `_emit_tree_txt` already ran it and wrote the result to `tree.txt`. The legacy bridge could read `tree.txt` instead, saving a redundant traversal. Not worth fixing until M69 removes the bridge.

## Resolved
