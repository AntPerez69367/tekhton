# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-01 | "M47"] `tests/test_context_cache.sh` is 311 lines, barely over the 300-line soft ceiling. Not a correctness issue — test files naturally accumulate assertions — but worth noting for the cleanup log.
- [ ] [2026-04-01 | "M47"] M47 milestone spec §1 lists `_CACHED_HUMAN_NOTES_BLOCK` as a cache target; it was not implemented (notes are read dynamically by `notes.sh` helpers). The acceptance criteria tests don't require it, and the omission is harmless, but the spec/implementation divergence is worth noting.
- [ ] [2026-04-01 | "M47"] The implementation deviates from spec §2 ("modify `render_prompt()` in `lib/prompts.sh`") in favor of explicit accessor calls in each stage. The chosen approach is superior — it avoids implicit coupling in the template engine — but the milestone spec should be updated to reflect the actual approach.
(none)

## Resolved
