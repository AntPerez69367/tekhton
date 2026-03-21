# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-03-21 | "Implement Milestone 20: Incremental Rescan & Index Maintenance"] `rescan.sh` is sourced in the main execution pipeline (tekhton.sh line 277) even though no pipeline stage calls any rescan function at runtime. This adds sourcing overhead on every pipeline run. Consider sourcing only in the `--rescan` early-exit block, or document why runtime pipeline access is needed.
- [ ] [2026-03-21 | "Implement Milestone 20: Incremental Rescan & Index Maintenance"] `_generate_codebase_summary` (replan_brownfield.sh lines 20-21) duplicates the metadata extraction logic (`grep '<!-- Scan-Commit:'` + `sed`) rather than calling `_extract_scan_metadata` from rescan_helpers.sh. Acceptable here because `replan_brownfield.sh` sources `replan.sh`, not `rescan.sh`, so `_extract_scan_metadata` is unavailable in the `--replan` path. Minor code smell worth noting.
- [ ] [2026-03-21 | "Implement Milestone 20: Incremental Rescan & Index Maintenance"] No test file added for rescan functions (see Coverage Gaps).
- [ ] [2026-03-20 | "Resolve all observations in NON_BLOCKING_LOG.md. For each unresolved item, apply the fix, then mark it resolved. Continue until no unresolved observations remain."] `lib/drift_cleanup.sh` is 318 lines, slightly above the 300-line ceiling. Pre-existing; not introduced by this run.

## Resolved
