# Reviewer Report

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `lib/detect.sh:111` — `C#` in `_known_langs` is lowercased to `c#` by `tr '[:upper:]' '[:lower:]'`, but file-based detection uses the key `csharp` (see `lang_manifest[csharp]` and `_counts[csharp]`). The two paths emit different language identifiers for C#. Low practical impact (greenfield C# projects are rare and the fallback is display-only), but worth aligning in a future pass.
- `tests/test_detect_languages.sh:246` — The test uses `grep -qi "typescript.*|low|CLAUDE.md"` where `.*` between `typescript` and `|low|CLAUDE.md` is redundant (output is exactly `typescript|low|CLAUDE.md`). Cosmetic only; assertion passes correctly.

## Coverage Gaps
- No test verifies that the CLAUDE.md fallback is skipped when file-based detection produces output (i.e., a project with both source files and CLAUDE.md should not double-emit). The fallback is guarded by `[[ -z "$_detected_output" ]]` so it's logically correct, but a regression test for this guard would be valuable.

## Drift Observations
- `lib/detect.sh:128-130` — `printf '%s' "$_detected_output"` suppresses the trailing newline when output comes from the subshell capture (bash strips trailing newlines from `$()`), but the CLAUDE.md fallback path appends an explicit `$'\n'`. The two paths have slightly different trailing-newline behavior. Callers using `while IFS= read -r` are unaffected in practice, but the inconsistency is worth noting.
