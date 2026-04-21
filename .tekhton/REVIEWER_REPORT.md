# Reviewer Report — M111: Fix Milestone Splitting for DAG Mode

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `lib/milestone_split_dag.sh:78` — Security LOW (flagged by security agent, fixable): `echo "$sub_block" > "${milestone_dir}/${sub_file}"` relies solely on `_slugify` to strip path separators. Adding `[[ "$sub_file" == */* ]] && return 1` immediately before the write makes traversal safety unconditional regardless of future changes to `_slugify`.
- `tests/test_m111_dag_split_bugs.sh` is 304 lines — 4 lines over the 300-line soft ceiling. Trimming Path D (the exact-boundary test at line 274) or folding the summary block would bring it under without losing signal.

## Coverage Gaps
- No test verifies what happens after sub-milestones complete and a downstream milestone depending on the now-`split` parent is expected to become schedulable. Current behavior: such milestones are permanently blocked because `dag_deps_satisfied` only accepts `done` status. A test that marks sub-milestones done and asserts the downstream milestone enters the frontier (or documents that it does not) would make the behavioral contract explicit.

## Drift Observations
- `lib/milestone_split_dag.sh` + `lib/milestone_dag.sh`: After a DAG-mode split, downstream milestones whose `depends_on` field references the now-`split` parent will be permanently blocked. `dag_deps_satisfied` requires `done`; `split` does not satisfy it, and `_split_apply_dag` never rewrites downstream dep fields to point at the last sub-milestone. In a multi-milestone run where an intermediate milestone is split and has dependents, the pipeline will silently stall after all sub-milestones complete. Fix options: (a) have `_split_apply_dag` rewrite downstream dep references from `parent_id` to `last_sub_id`, or (b) have `dag_deps_satisfied` treat `split` as equivalent to `done` (simpler but would admit downstream runs before sub-milestones are themselves done — probably wrong). Option (a) is correct.
