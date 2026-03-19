# Scout Report: Milestone 15.1 — Bug Fixes

## Relevant Files

- **lib/notes.sh** — Contains `should_claim_notes()` (lines 12-31) which currently checks both flags AND task text patterns. Must be simplified to flag-only gating per spec.
- **lib/config_defaults.sh** — Sets `AUTO_COMMIT` default (line 129) to unconditional `true`. Must become conditional on `MILESTONE_MODE`.
- **stages/coder.sh** — Invokes human notes claiming at line 328 with gating at line 327. Gate is already present but needs verification that `HUMAN_NOTES_BLOCK` is set to empty string (line 331).
- **lib/drift_cleanup.sh** — Already contains `clear_resolved_nonblocking_notes()` function (lines 220-265) fully implemented per spec. No changes required.
- **tekhton.sh** — Flag parsing (lines 528-541) includes `--with-notes` (line 529) but lacks `--human [TAG]` parsing. Also needs usage documentation for the new flag.

## Key Symbols

- `should_claim_notes()` — lib/notes.sh:12 — Needs simplification to flag-only logic
- `resolve_human_notes()` — lib/notes.sh:89 — Already handles `_PIPELINE_EXIT_CODE` for success-without-summary case (lines 187-191)
- `claim_human_notes()` — lib/notes.sh:63 — Called from coder.sh:328 via gating
- `AUTO_COMMIT` — lib/config_defaults.sh:129 — Default value, needs conditional logic
- `clear_resolved_nonblocking_notes()` — lib/drift_cleanup.sh:223 — Already fully implemented, ready for integration
- Flag parsing block — tekhton.sh:528-541 — Where `--human` needs to be added

## Suspected Root Cause Areas

- **Phantom notes injection**: `should_claim_notes()` at lib/notes.sh:26 uses grep pattern matching on task text to auto-claim notes. Remove this entire block (lines 25-28) to enforce flag-only gating.
- **AUTO_COMMIT default inconsistency**: lib/config_defaults.sh:129 hardcodes `AUTO_COMMIT=true` for all runs. Must be conditional: check `MILESTONE_MODE` and default accordingly.
- **Missing --human flag**: tekhton.sh flag parsing (lines 528-541) lacks case for `--human [TAG]`. Needs addition similar to `--with-notes` pattern but with optional argument capture.
- **Notes gating already correct**: coder.sh:327-331 already gates `claim_human_notes()` behind `should_claim_notes` and sets `HUMAN_NOTES_BLOCK=""` when notes aren't claimed. No changes needed there.
- **Resolved cleanup not wired**: lib/drift_cleanup.sh:223 has `clear_resolved_nonblocking_notes()` implemented but is not called from any finalization path (Milestone 15.3 will wire it).

## Complexity Estimate

Files to modify: 2
Estimated lines of change: 40
Interconnected systems: medium
Recommended coder turns: 20
Recommended reviewer turns: 8
Recommended tester turns: 15
