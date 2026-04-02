# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-02 | "Fix: --init merge strategy crashes with 'render_prompt: command not found' (exit 127). In lib/artifact_handler_ops.sh, _handle_strategy_merge() calls render_prompt() at line 119 but prompts.sh is never sourced during the --init code path. Add a lazy-load guard before the render_prompt call (same pattern as lines 99-103 which lazy-load plan.sh for _call_planning_batch): check if render_prompt is defined via 'type render_prompt', and if not, source ${_ops_dir}/prompts.sh. The prompt template prompts/artifact_merge.prompt.md already exists. No other files need changes."] `lib/artifact_handler_ops.sh` is 308 lines — 8 over the 300-line soft ceiling. The change added ~5 net new lines; consider extracting the merge prompt/batch orchestration into a `_run_merge_batch()` helper during the next cleanup pass.
(none)

## Resolved
