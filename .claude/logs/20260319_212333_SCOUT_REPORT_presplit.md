# Scout Report: Milestone 15.2.2 — Archival Removal of [DONE] Lines and One-Time CLAUDE.md Migration

## Relevant Files

- `lib/milestone_archival.sh` — Contains `archive_completed_milestone()` function that currently replaces [DONE] milestone blocks with one-liner summaries. Must be modified to remove [DONE] lines entirely and handle archival pointer comment insertion.
- `CLAUDE.md` — Contains 26 accumulated `#### [DONE] Milestone N: Title` one-liner lines (lines 272-276 and 301-323) under two separate `### Milestone Plan` sections. Must be cleaned up as a one-time migration.
- `lib/milestones.sh` — Contains `is_milestone_done()` and `get_milestone_title()` helper functions used by `archive_completed_milestone()`. No modifications needed but used as reference.
- `lib/milestone_ops.sh` — Contains milestone-related utilities. References `mark_milestone_done()` which will be added in M15.2.1 prerequisite.
- `tekhton.sh` — Calls `archive_completed_milestone()` and `archive_all_completed_milestones()` at lines 768, 1173, 1191. Current behavior will change but API remains the same.

## Key Symbols

- `archive_completed_milestone(milestone_num, claude_md_path)` — `lib/milestone_archival.sh:110-190`
- `archive_all_completed_milestones(claude_md_path)` — `lib/milestone_archival.sh:263-296`
- `_extract_milestone_block(milestone_num, claude_md_path)` — `lib/milestone_archival.sh:20-65`
- `_get_initiative_name(claude_md_path, milestone_num)` — `lib/milestone_archival.sh:67-87`
- `is_milestone_done(milestone_num, claude_md_path)` — `lib/milestones.sh:132`
- `get_milestone_title(milestone_num, claude_md_path)` — `lib/milestones.sh:121`

## Suspected Root Cause Areas

- **AWK block replacement logic** (`lib/milestone_archival.sh` lines 157-184): Currently outputs `summary_line` when matching the [DONE] milestone heading. Must change to output nothing (remove the line) instead.
- **Comment insertion logic**: Currently absent. New code must check for `<!-- See MILESTONE_ARCHIVE.md for completed milestones -->` in the `### Milestone Plan` section and insert if missing, using `grep` first to avoid duplicates.
- **Blank line cleanup**: Currently absent. New code must collapse 3+ consecutive blank lines down to 2 after the AWK rewrite, using a separate `sed` or `awk` pass.
- **One-time migration**: 26 [DONE] one-liner milestones exist in CLAUDE.md (lines 272-276 under Planning initiative, lines 301-323 under Adaptive Pipeline 2.0). These are single-line summaries with no content block below them — the full blocks are already in MILESTONE_ARCHIVE.md. Must be manually removed from CLAUDE.md and replaced with archival pointer comments.

## Complexity Estimate

Files to modify: 2
Estimated lines of change: 85
Interconnected systems: low
Recommended coder turns: 28
Recommended reviewer turns: 6
Recommended tester turns: 12
