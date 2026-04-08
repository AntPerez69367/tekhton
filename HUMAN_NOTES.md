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
- [x] [BUG] `--plan --answers FILE` DESIGN.md synthesis writes tool-output summary instead of document content. Root cause: `_call_planning_batch()` (lib/plan_batch.sh) runs Claude with `--max-turns > 1`, which gives the model tool access. During synthesis in `run_plan_interview()` (stages/plan_interview.sh), Claude uses the Write tool to create DESIGN.md (with actual content) and then emits only a summary confirmation as text output. The shell captures that summary in `design_content` and immediately overwrites DESIGN.md with it, destroying the real content. Symptoms: (a) DESIGN.md contains a bulleted description of what it would contain ("DESIGN.md has been written. It synthesizes all interview answers into..."), or (b) DESIGN.md contains a permissions-request message when `--dangerously-skip-permissions` is not effective. Fix: in `run_plan_interview()`, before writing `design_content` to disk, check whether DESIGN.md already exists on disk with substantive content (i.e. the tool wrote it successfully) — if so, skip the overwrite. Also add an explicit directive to `prompts/plan_interview.prompt.md` that Claude must NOT use file-write tools and must output the document content directly as its text response, since `_call_planning_batch()` is designed to capture text output for the shell to write. Fix should also apply to `run_plan_generate()` in stages/plan_generate.sh, which uses the same pattern for CLAUDE.md.


## Polish
