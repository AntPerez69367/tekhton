# Reviewer Report — M41: Note Triage & Sizing Gate (Cycle 2)

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `lib/notes_triage.sh` is 589 lines — nearly 2x the 300-line soft ceiling. The file is logically partitioned (heuristics, agent escalation, promotion flow, pipeline integration, report) and could be split into `notes_triage_core.sh` + `notes_triage_flow.sh`.
- `lib/notes_triage.sh:170` — `$(date +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)` falls back to the identical command. The fallback is a no-op; if the intent is a timezone-safe fallback, the two calls should differ.
- `lib/notes_triage.sh:226-229` — Template variables (`TRIAGE_NOTE_TEXT`, `TRIAGE_NOTE_TAG`, etc.) are exported into the environment and never unset after agent escalation. Consistent with the pipeline's existing pattern, but worth noting for future cleanup.

## Coverage Gaps
- No test exercises the confirm-mode path of `_prompt_promote_note` via command substitution — the stdout-contamination path (now fixed) was untested, which is why the bug escaped detection originally.
- Suite 6 (cached triage) doesn't prove the cache short-circuit actually fires — note n04 ("Fix button alignment") scores `fit` via the heuristic regardless of cache, so the test passes even if `_NM_TRIAGE` is never populated by `_parse_note_metadata`.
- No test for `triage_bulk_warn` with a tag filter (the `"BUG"` filter branch at line 460 is uncovered).

## ACP Verdicts
None declared in CODER_SUMMARY.md.

## Drift Observations
- `lib/notes_triage.sh:46-48` — Uses `echo "$lower_text" | grep -qE "$ind"` for regex matching. The `printf '%s\n' "$lower_text"` form is the shellcheck-preferred pattern for piping variables (avoids edge cases where `$lower_text` starts with `-`). Low-impact given typical note text, but worth noting for consistency with the rest of the codebase.

## Prior Blocker Verification

**Simple Blocker (cycle 1):** `lib/notes_triage.sh:283` — `_prompt_promote_note` was emitting display lines to stdout, contaminating the `choice=$(_prompt_promote_note ...)` capture so that `case "$choice" in p)` never matched.

**Status: FIXED.** Lines 289–294 and 312 now redirect all informational `echo` calls to stderr (`>&2`). Only the final `echo "$choice"` at line 315 writes to stdout. The caller at line 421–422 will receive a clean single-char value (`p`, `k`, or `s`) and the case match will succeed correctly.
