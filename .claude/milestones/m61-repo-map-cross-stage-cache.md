# Milestone 61: Repo Map Cross-Stage Cache
<!-- milestone-meta
id: "61"
status: "pending"
-->

## Overview

The tree-sitter repo map is regenerated from scratch for every pipeline stage
(scout, coder, review, tester, architect). Each invocation calls `run_repo_map()`
which spawns `tools/repo_map.py`, runs PageRank, and formats output — even though
the underlying files haven't changed between stages within a single run. Only the
*slice* differs per stage.

This milestone introduces an intra-run repo map cache so the full map is generated
once and sliced per stage without re-invoking the Python tool.

Depends on M56 (last completed milestone) for stable pipeline baseline.

## Scope

### 1. Run-Scoped Map Cache

**File:** `lib/indexer.sh`

After the first successful `run_repo_map()` call, write the full map content to
a run-scoped cache file (e.g., `.claude/logs/<run_id>/REPO_MAP_CACHE.md`). On
subsequent calls within the same run:
- Check if cache file exists and is from the current run (compare `RUN_ID`)
- If cached, load from file instead of invoking Python tool
- If task context differs significantly (different task string), allow optional
  re-generation via a `force_refresh` parameter

### 2. Stage-Specific Slicing from Cache

**File:** `lib/indexer.sh`

`get_repo_map_slice()` already operates on the in-memory `REPO_MAP_CONTENT`
variable. Ensure it works identically whether content came from cache or fresh
generation. No changes needed to slice logic itself — only to the source.

### 3. Cache Invalidation

**File:** `lib/indexer.sh`

Add `invalidate_run_map_cache()` callable from stages that modify files
mid-pipeline (e.g., after coder writes new files). The review and tester stages
should call this if they detect the coder created new files that weren't in the
original map. Check `CODER_SUMMARY.md` for "Created:" entries.

### 4. Skip Regeneration on Review Cycle 2+

**File:** `stages/review.sh`

Review cycles 2+ currently reset `REPO_MAP_CONTENT=""` and regenerate. Since
review rework only modifies existing files (not creates new ones), reuse the
cached map and re-slice to the same file list. Add a guard that only regenerates
if the file list changed between review cycles.

### 5. Timing Integration

**File:** `lib/indexer.sh`

Track cache hits vs. misses in `_phase_start`/`_phase_end` instrumentation.
Report in TIMING_REPORT.md:
```
Repo map: 1 generation + 3 cache hits (saved ~Xs)
```

## Migration Impact

No new config keys required. Cache is automatic and internal. Existing
`REPO_MAP_ENABLED` and `REPO_MAP_TOKEN_BUDGET` settings continue to work
unchanged.

## Acceptance Criteria

- Full repo map generated at most once per run (unless invalidated)
- Subsequent stages load from cache file, not Python tool
- `get_repo_map_slice()` produces identical output from cached vs. fresh content
- Review cycle 2+ reuses cached map without regeneration
- Cache invalidation triggers correctly when coder creates new files
- TIMING_REPORT.md shows cache hit/miss statistics
- All existing tests pass
- No measurable difference in prompt content between cached and uncached runs

Tests:
- Cache file written after first `run_repo_map()` call
- Second call within same run reads from cache (verify no Python invocation)
- `invalidate_run_map_cache()` forces regeneration on next call
- Review cycle 2 reuses map without reset
- Different `RUN_ID` does not match stale cache

Watch For:
- The task string passed to `run_repo_map()` affects PageRank weighting. Since
  the scout and coder may pass different task contexts, the cached map should use
  the original task. Slicing handles per-stage relevance — the full map just needs
  to include all files.
- Cache file must be cleaned up by the existing run log cleanup mechanism.
- Ensure `REPO_MAP_CONTENT` export still works correctly for template rendering
  after loading from cache.

Seeds Forward:
- Reduced Python invocations directly cut run time
- Cache hit statistics feed into M66 (Efficiency Dashboard Metrics) if created
