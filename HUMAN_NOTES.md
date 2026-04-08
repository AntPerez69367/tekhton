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
- [x] [FEAT] Add test isolation guardrails to prevent Tekhton from creating state-dependent tests. (1) `prompts/tester.prompt.md` — add to "CRITICAL: Test Integrity Rules": tests must never read live repo artifact files (build reports, logs, config state) directly; always create controlled fixtures in a temp directory. Tests that validate specific run outcomes belong in the commit message, not the test suite. (2) `prompts/test_audit.prompt.md` — add a 7th audit rubric point ("Test Isolation"): flag tests that read mutable project files without creating their own fixture copies. Severity: HIGH.

## Bugs

## Polish
