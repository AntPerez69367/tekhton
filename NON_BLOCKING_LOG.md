# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in ${REVIEWER_REPORT_FILE}.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-13 | "M81"] `lib/init_report_banner.sh` is 355 lines — still over the 300-line ceiling. No functional impact; log for future cleanup sweep.
- [x] [2026-04-13 | "M81"] Milestone-detection logic (MANIFEST.cfg presence + pending grep) remains duplicated verbatim in `_emit_next_section` and `_emit_auto_prompt` (lines 271–286 and 323–336). Still a candidate for extraction to `_init_detect_milestone_state`, but not a blocker.
- [ ] [2026-04-13 | "M81"] `lib/prompts.sh` was not updated to register `INIT_AUTO_PROMPT` as a template variable (as noted in cycle 1). No functional impact since no prompt currently uses it, but the variable registry remains incomplete.
- [ ] [2026-04-13 | "M80"] `prompts/draft_milestones.prompt.md:34-35` — Empty `{{IF:DRAFT_SEED_DESCRIPTION}}...{{ENDIF:DRAFT_SEED_DESCRIPTION}}` block is still present (dead code, likely a copy-paste residue). Remove for clarity.
- [ ] [2026-04-13 | "M80"] `lib/draft_milestones.sh:87` — `head -"$count"` where `$count` comes from `DRAFT_MILESTONES_SEED_EXEMPLARS`. `_clamp_config_value` enforces an upper bound but does not enforce the value is an integer. A non-integer config value passes through to `head` as a malformed flag. Add `[[ "$count" =~ ^[0-9]+$ ]] || count=3` before the pipeline.
<!-- Items added here by the pipeline. Mark [x] when addressed. -->

## Resolved
