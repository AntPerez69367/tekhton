# Reviewer Report — M33: Human Mode Completion Loop & State Fidelity (Re-review Cycle 2)

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- **Crash-recovery resume gap (state.sh / tekhton.sh)**: In the exec-based resume path for single-note human mode, `CURRENT_NOTE_LINE` is exported to the child process env (tekhton.sh:991) but then unconditionally overwritten by `pick_next_note` at tekhton.sh:1382. Since the claimed note is in `[~]` state and `pick_next_note` only scans `[ ]` notes, a note that was `[~]` at crash time is invisible to resume. The gap is only in crash/SIGINT scenarios where `finalize_run` never runs. Suggest a future guard: if `CURRENT_NOTE_LINE` is already set from env AND `HUMAN_SINGLE_NOTE=true`, skip `pick_next_note` and restore `TASK` from the env value directly.
- **Misleading log in coder.sh elif branch (stages/coder.sh:435)**: The message "Human notes exist but no notes flag set" can fire when `HUMAN_MODE=true` (single-note mode), where notes ARE being handled via `claim_single_note`. The condition matches whenever notes remain regardless of mode — confusing to operators who ran `--human`. Not harmful, just noisy.
- **`_hook_resolve_notes` fallthrough edge case (lib/finalize.sh:115)**: When `HUMAN_MODE=true` but `CURRENT_NOTE_LINE` is empty and the pipeline fails, no `[~]` reset occurs. Stuck `[~]` notes from this path are cleaned up only by the safety net on the next successful run. Acceptable given the scenario requires an invariant violation, but worth documenting.

## Coverage Gaps
- No test covers exec-resume with a `[~]` note (crash recovery scenario): `test_human_mode_state_resume.sh` validates state serialization and `_build_resume_flag` but does not simulate a resumed invocation where the note is `[~]` and `pick_next_note` is called.
- `test_human_mode_resolve_notes_edge.sh` should include a case for `HUMAN_MODE=true` + empty `CURRENT_NOTE_LINE` + non-zero exit path to document that `[~]` notes are not reset until the next successful run.

## ACP Verdicts
None

## Drift Observations
- `lib/state.sh` — Prior cycle flagged missing `set -euo pipefail`; confirmed fixed in this cycle (line 2). Other sourced-only lib files not touched by M33 may have the same omission — worth a sweep across the full `lib/` directory.
