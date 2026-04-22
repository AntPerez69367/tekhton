## Summary

This change set covers five files: three shell library files (`lib/tui.sh`, `lib/tui_ops.sh`,
`lib/tui_ops_substage.sh`), one DAG-mode helper (`lib/milestone_split_dag.sh`), and one Python
test file (`tools/tests/test_tui_render_timings.py`). The changes are internal TUI state
management and a targeted path-traversal guard addition. No authentication, network, credentials,
or user-facing input handling is involved. The TUI changes are pure in-process state mutations
with no shell injection surface. The milestone-split DAG change introduces a filename path-separator
guard that is correct and effective for the primary threat (slash-based traversal); a minor
belt-and-suspenders gap exists but carries negligible practical risk.

## Findings

- [LOW] [category:A01] [lib/milestone_split_dag.sh:81] fixable:yes — The new `*/*` guard correctly blocks filenames containing a `/` (including `../relative` patterns), but does not explicitly reject the degenerate case of a bare `..` with no slash. Writing to `${milestone_dir}/..` would fail at the OS level (it is a directory, not a file) so no actual traversal is possible, but adding `|| [[ "$sub_file" == ".." ]]` to the guard makes the defensive intent self-documenting and robust against any OS edge case.

## Verdict
CLEAN
