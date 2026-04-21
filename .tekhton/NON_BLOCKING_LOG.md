# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-21 | "M111"] `lib/milestone_split_dag.sh:78` — Security LOW (flagged by security agent, fixable): `echo "$sub_block" > "${milestone_dir}/${sub_file}"` relies solely on `_slugify` to strip path separators. Adding `[[ "$sub_file" == */* ]] && return 1` immediately before the write makes traversal safety unconditional regardless of future changes to `_slugify`.
- [x] [2026-04-21 | "M111"] `tests/test_m111_dag_split_bugs.sh` is 304 lines — 4 lines over the 300-line soft ceiling. Trimming Path D (the exact-boundary test at line 274) or folding the summary block would bring it under without losing signal.

## Resolved
