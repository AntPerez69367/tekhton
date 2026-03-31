# Jr Coder Summary — M41: Note Triage & Sizing Gate

## What Was Fixed

- **lib/notes_triage.sh:283** — Fixed stdout/stderr contamination in `_prompt_promote_note`. All informational display lines (lines 289–294, 312) now redirect to stderr (`>&2`), keeping only the final single-character response on stdout. This allows the caller's command substitution `choice=$(_prompt_promote_note ...)` to capture a clean response instead of a multi-line string, enabling the `case` statement at line 422 to match correctly on `"p"`, `"k"`, or `"s"`.

## Files Modified

- `lib/notes_triage.sh`

## Verification

- ✓ `bash -n lib/notes_triage.sh` — syntax check passed
- ✓ `shellcheck lib/notes_triage.sh` — zero warnings
