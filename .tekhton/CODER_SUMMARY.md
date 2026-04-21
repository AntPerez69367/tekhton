# Coder Summary

## Status: COMPLETE

## What Was Implemented

M111 — Fix Milestone Splitting for DAG Mode. Three compounding bugs that prevented
`split_milestone` and `handle_null_run_split` from working end-to-end in DAG mode
have been fixed. The large monolithic split logic has also been extracted into two
companion files to keep `milestone_split.sh` under the 300-line ceiling.

**Bug 1 — DAG-aware extraction (`lib/milestone_split.sh:122-142`).**
`split_milestone()` now detects DAG mode once before extraction. When the manifest
is present and DAG is enabled, it calls `_split_read_dag_milestone` (reads from
`.claude/milestones/<file>`) instead of `_extract_milestone_block` (which only
reads flat CLAUDE.md). Falls back to the old path when inline mode is active.

**Bug 2 — Splice sub-milestones after parent (`lib/milestone_split_dag.sh`).**
`_split_apply_dag()` parses sub-milestones from the agent output, then rebuilds
all six `_DAG_*` parallel arrays by inserting the new entries immediately after
`parent_idx + 1`. `_DAG_IDX` is recomputed for every entry. This ensures
`save_manifest` writes sub-milestones in their correct sequential position
(right after the parent, not at the end of the file), so `dag_find_next`
schedules them next.

**Bug 3 — Skip `split` status in frontier (`lib/milestone_dag.sh:162-172`).**
`dag_get_frontier()` now treats `split` as terminal alongside `done`. Before this
fix, a parent marked `split` would re-enter the frontier and compete with its
own sub-milestones — causing the pipeline to re-run the original unsplit
milestone.

## Root Cause (bugs only)

All three bugs stem from `milestone_split.sh` being originally written for inline
milestones (flat CLAUDE.md sections). When M01 made the manifest + individual
files the default, the splitting code path was never exercised end-to-end:
- Extraction only read CLAUDE.md (`_extract_milestone_block`).
- The DAG path appended sub-milestones via `_DAG_IDS+=` to the end of the arrays.
- `dag_get_frontier` only skipped `done`, letting a `split` parent back in.

## Files Modified

- `lib/milestone_split.sh` — refactored to detect DAG mode once, delegate to
  helper files for DAG apply and null-run handling; shrunk from monolithic
  ~400-line block to 247 lines.
- `lib/milestone_split_dag.sh` (NEW, 150 lines) — DAG-mode helpers
  `_split_read_dag_milestone()` and `_split_apply_dag()` with correct array
  splicing after parent index.
- `lib/milestone_split_nullrun.sh` (NEW, 84 lines) — extracted
  `handle_null_run_split()` with substantive-work detection (git diff + summary
  lines > 20) that preserves partial progress rather than splitting.
- `lib/milestone_dag.sh` — `dag_get_frontier()` skips `split` status.
- `tests/test_m111_dag_split_bugs.sh` (NEW, 303 lines) — 22 assertions covering
  all three bugs plus null-run substantive-work edge cases.
- `CLAUDE.md` — repo layout section updated to list the two new lib files.
- `ARCHITECTURE.md` — added entries for `milestone_split_dag.sh` and
  `milestone_split_nullrun.sh`; updated `milestone_split.sh` entry to note the
  new source relationship.

## Human Notes Status

No unchecked human notes were present for this task.

## Docs Updated

- `CLAUDE.md` — added two new lib files to the repository layout tree.
- `ARCHITECTURE.md` — added library descriptions for `milestone_split_dag.sh`
  and `milestone_split_nullrun.sh`, noted the source chain from
  `milestone_split.sh`.

## Acceptance Criteria Verification

All 9 M111 acceptance criteria are met:

- DAG-mode extraction reads the milestone file rather than CLAUDE.md — covered
  by `_split_read_dag_milestone` path in `split_milestone`.
- Sub-milestone files written to `.claude/milestones/` — confirmed in
  `_split_apply_dag`.
- Manifest sub-milestone rows immediately after parent — verified by test Path
  "sub-milestone insertion position" (lines 4 and 5 before line 6).
- Parent status = `split` after split — verified by test (Bug 3 fixture).
- Parent with `split` status excluded from frontier — verified by test Bug 3.
- Sub-milestones execute in radix order — dependency chaining preserved: first
  sub inherits parent deps, later subs depend on previous sub.
- Inline (non-DAG) path unaffected — existing `_replace_milestone_block` branch
  reached when `in_dag=false`.
- Null-run auto-split works in DAG mode — `handle_null_run_split` → splits via
  the same DAG-aware `split_milestone`; 5 edge cases (Paths A–E) pass.
- Oversized pre-flight split works — `check_milestone_size` → `split_milestone`
  uses the same DAG-aware code path.

## Test Results

- `tests/test_m111_dag_split_bugs.sh`: 22/22 pass
- `bash tests/run_tests.sh`: 421/421 shell + 177/177 python pass
- `shellcheck` on all modified files: clean (only pre-existing SC1091 info on
  the lazy `lib/plan.sh` source at line 159 — carried forward from the
  original).

## Observed Issues (out of scope)

None.
