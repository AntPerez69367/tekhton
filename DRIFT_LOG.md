# Drift Log

## Metadata
- Last audit: 2026-03-24
- Runs since audit: 5

## Unresolved Observations
- [2026-03-24 | "Implement Milestone 23: Dry-Run & Preview Mode"] `lib/dry_run.sh:252`: `_parse_scout_preview` uses bullet-point line count as proxy for "files modified." Scout reports include recommendation lists, section headers with bullets, and other non-file bullet content. This inflates the displayed file count in the preview. Consider tightening the grep pattern to match file path characters (e.g., `[-*]s+S+.S+`) or relabeling to "~N items."
- [2026-03-24 | "Implement Milestone 22: Init UX Overhaul"] `lib/init_config.sh:177` — `_preserve_user_config()` uses grep pattern `'^[A-Z_]+='`, which silently drops any config key containing a digit (e.g. a hypothetical `V2_FEATURE=...`). `_merge_preserved_values()` uses the same `^([A-Z_]+)=` regex. Both are consistent with the current key set (all uppercase alpha + underscore), but the pairing is fragile if a digit-bearing key is ever added. Not a current bug.
- [2026-03-24 | "Implement Milestone 21: Version Migration Framework & Project Upgrade"] `lib/diagnose_rules.sh` now has 12 rules but the file-level comment header still lists only 10 named rules (lines 14-21). The `_rule_test_audit_failure` and `_rule_version_mismatch` entries are missing from the header block. Low priority, but the header is the first thing readers scan.

## Resolved
- [2026-03-22 | RESOLVED 2026-03-22] All three prior drift entries (SX-1, SX-2, SF-1) were fully addressed in commit 58c3ea3.
- [2026-03-22 | RESOLVED 2026-03-22] `lib/indexer_helpers.sh` — `&&`-chained seen-set pattern was refactored to `if/then/fi` style in commit 58c3ea3. No remaining occurrences of this pattern in the codebase.
