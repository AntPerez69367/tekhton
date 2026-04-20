# Drift Log

## Metadata
- Last audit: 2026-04-19
- Runs since audit: 1

## Unresolved Observations
- [2026-04-19 | "M104"] `lib/tui_ops.sh` accesses globals declared in `lib/tui.sh` (`_TUI_ACTIVE`, `_TUI_RECENT_EVENTS`, `_TUI_STAGES_COMPLETE`, `_TUI_CURRENT_STAGE_*`, `_TUI_AGENT_*`, `_tui_write_status`) with no `# shellcheck source=tui.sh` directive. Consistent with the pre-existing gap in `tui_helpers.sh` — not new drift.

## Resolved
- [RESOLVED 2026-04-19] `lib/tui_helpers.sh:_tui_escape` and the `_out_json_escape` function in `lib/output_format.sh` (flagged in M102) implement the same JSON string escaping logic independently. Now that M103 adds tests that exercise both paths, this divergence is more visible — a future bug fix to one that misses the other will produce inconsistent escaping between CLI and TUI paths. Candidate for consolidation in a cleanup pass.
- [RESOLVED 2026-04-19] `lib/output_format.sh:_out_json_escape` and `lib/tui_helpers.sh:_tui_escape` implement identical JSON string escape logic (backslash doubling, quote escaping, newline/CR/tab). As the output bus matures these should be consolidated into a single authoritative function rather than maintained in parallel — a future edit to one that isn't mirrored in the other will produce inconsistent escaping between CLI and TUI paths.
- [RESOLVED 2026-04-19] `lib/finalize.sh:532-534` — comment references milestone numbers (M97, M102) inline. These rotate as the history of the file extends. The load-bearing observation (action_items accumulate in `_hook_commit` so `_hook_tui_complete` must run last) should be expressed as a causal statement rather than a changelog entry.
- [RESOLVED 2026-04-19] `lib/init_helpers_display.sh` was extracted from `init_helpers.sh` to keep `init_helpers.sh` under the 300-line ceiling, but the new file itself uses `echo -e` with aliased ANSI locals — a pattern that the lint test was designed to eliminate. The extraction preserved the old style rather than converting it, creating a latent gap in lint coverage.
- [RESOLVED 2026-04-19] `test_output_lint.sh` checks `lib/` and `stages/` but excludes only `lib/common.sh`, `lib/output.sh`, `lib/output_format.sh`. If `lib/output_format.sh` itself ever exceeds 300 lines and is split, the exclusion list will need updating — a fragile coupling between file layout and lint configuration.
- [RESOLVED 2026-04-19] **OBS-1 and OBS-2** (both entries from the 2026-04-18 audit): Both were already self-annotated "Verified stale. No action required." by the prior architect pass. Confirmed by direct file inspection:
- [RESOLVED 2026-04-19] `lib/common.sh` line 110 is a blank-line comment separator; no formatting issue.
- [RESOLVED 2026-04-19] `lib/tui_helpers.sh:_tui_json_build_status` emits no `"stage"` field; no duplication with `"stage_label"`. No code changes are warranted. The only required action is closing these observations in the drift log.
