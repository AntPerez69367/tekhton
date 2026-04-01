# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-01 | "M50"] `lib/progress.sh:183-206` (`_get_timing_breakdown`): if `_STAGE_DURATION` is declared but all per-stage values are 0 (e.g. very early pipeline failure), the function emits `{,"total":0}` — invalid JSON. The guard at the top only checks if the array exists, not if it has non-zero entries. Fix: track a `first` flag for the total field too, or emit `{}` when no non-zero stages were found.
- [ ] [2026-04-01 | "M50"] `stages/review.sh:164-168`: `log_decision "Reviewer requires changes"` uses `${HAS_COMPLEX:-0}` / `${HAS_SIMPLE:-0}` before those counts are computed for the current cycle (they're set at line 199). The message will always log "0 complex, 0 simple" on the first occurrence per cycle, and stale counts from the prior cycle on subsequent ones. The routing decisions at lines 214 and 248 correctly log actual counts. Fix: move the `log_decision` for "Reviewer requires changes" to after the blocker counts are computed (after line 208).
- [ ] [2026-04-01 | "M50"] `lib/progress.sh:184`: `declare -p _STAGE_DURATION &>/dev/null 2>&1` — the trailing `2>&1` is redundant after `&>/dev/null` (which already redirects both streams). Not harmful but may trigger SC2069 depending on shellcheck version. Use `&>/dev/null` alone.

## Resolved
