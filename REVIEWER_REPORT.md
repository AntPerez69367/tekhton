# Reviewer Report — M47: Intra-Run Context Cache

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `tests/test_context_cache.sh` is 311 lines, barely over the 300-line soft ceiling. Not a correctness issue — test files naturally accumulate assertions — but worth noting for the cleanup log.
- M47 milestone spec §1 lists `_CACHED_HUMAN_NOTES_BLOCK` as a cache target; it was not implemented (notes are read dynamically by `notes.sh` helpers). The acceptance criteria tests don't require it, and the omission is harmless, but the spec/implementation divergence is worth noting.
- The implementation deviates from spec §2 ("modify `render_prompt()` in `lib/prompts.sh`") in favor of explicit accessor calls in each stage. The chosen approach is superior — it avoids implicit coupling in the template engine — but the milestone spec should be updated to reflect the actual approach.

## Coverage Gaps
- `_get_cached_milestone_block()` has no direct unit test. The invalidation test (Test 6) clears `_CACHED_MILESTONE_BLOCK` directly but never exercises the accessor's fallback path (`build_milestone_window` call on cache miss). A test with `MILESTONE_MODE=true` and a stub `build_milestone_window` would close this gap.
- Keyword extraction cache in `context_compiler.sh` (the `_CACHED_KEYWORDS_KEY`/`_CACHED_KEYWORDS` path) has no corresponding test in `test_context_cache.sh`. Should be covered in `test_context_cache.sh` or a dedicated `test_context_compiler.sh` test.

## Drift Observations
- `lib/context_cache.sh:144` — `_get_cached_drift_log_content` checks `[[ -n "$_CACHED_DRIFT_LOG_CONTENT" ]]` before returning the cached value (enabling fallback after `invalidate_drift_cache`), while `_get_cached_architecture_content` and `_get_cached_architecture_log_content` do not. The asymmetry is correct (only drift has an invalidator), but the pattern is subtly different from the rest of the accessors. A comment explaining why drift uniquely requires the non-empty guard would help future maintainers.
- `lib/milestone_ops.sh:227-229` — `invalidate_milestone_cache` is called only in the DAG path of `mark_milestone_done`. The inline path silently skips it. This is correct (cache only holds DAG-mode window data), but the guard condition isn't explained inline; the comment only references M47 without explaining why inline mode is exempt.

## ACP Verdicts
(No Architecture Change Proposals in CODER_SUMMARY.md.)
