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




- [x] [BUG] `--init` shows A/M/T/I prompt and "Prior Tekhton installation detected" after a fresh `--plan` run. Root cause: `plan_generate.sh` (and `init_synthesize.sh`'s `_synthesize_claude()` for `--plan-from-index`) write CLAUDE.md without the `<!-- tekhton-managed -->` marker, so `detect_ai_artifacts.sh` classifies it as the ambiguous `"Claude/Tekhton"` path (medium confidence) and triggers the archive/merge/tidy/ignore menu. The `.claude/milestones/` dir is correctly classified as Tekhton-high and routes to `_handle_tekhton_reinit()` (informational only), but CLAUDE.md fires a second, separate handler. Fix is two-part: (1) In both `stages/plan_generate.sh` and `stages/init_synthesize.sh` (`_synthesize_claude`), append `<!-- tekhton-managed -->` to CLAUDE.md **post-write on-disk** (after `_trim_document_preamble` runs on any captured output — do NOT inject into the captured string or it gets stripped). This is the only place in the codebase that checks the marker; no other logic reads it, no write-guards, no context/replan/rescan dependencies. Impact on tests: `test_plan_generate_tool_write_guard.sh` has `head -1` == `# Tekhton CLAUDE.md` assertions (Test 1 line 123, Test 2 line 174) which are safe since we append, and an exact `line_count -eq 30` assertion (Test 1 line 135) which needs updating to 31. (2) In `_handle_tekhton_reinit()` (`lib/artifact_handler_ops.sh`) — which is purely cosmetic (no flags, no execution effect on Phases 2–7) — add a branch: if `.claude/milestones/MANIFEST.cfg` exists but `.claude/pipeline.conf` does NOT, emit "Found completed --plan output — proceeding with initialization" instead of "Prior Tekhton installation detected." Existing tests (`test_artifact_handler_ops.sh` lines 350–387) are unaffected; add a new test case for the MANIFEST-present/no-conf branch.

## Polish
