# Human Notes
<!-- notes-format: v2 -->
<!-- IDs are auto-managed by Tekhton. Do not remove note: comments. -->

Add your observations below as unchecked items. The pipeline will inject
unchecked items into the next coder run and archive them when done.

Use `- [ ]` for new notes. Use `- [x]` to mark items you want to defer/skip.

Prefix each note with a priority tag so the pipeline can scope runs correctly:
- `[BUG]` — something is broken, needs fixing before new features
- `[FEAT]` — new mechanic or system, architectural work
- `[POLISH]` — visual/UX improvement, no logic changes


## Features

## Bugs

- [x] [BUG] Greenfield plan Milestone Summary incorrectly reports "0 milestones" and "No milestone headings found in CLAUDE.md" even when milestones were successfully generated in `.claude/milestones/`. The summary display logic is looking for milestone headings in CLAUDE.md (the old inline location) instead of counting files in the DAG milestone directory. Fix the milestone count and warning message in the plan review/summary display to check the milestone directory when `MILESTONE_DAG_ENABLED` is true.

## Polish
