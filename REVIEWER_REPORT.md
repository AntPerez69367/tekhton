## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `stages/plan_interview.sh:364` and `stages/plan_generate.sh:108` — when the guard fires, the rescued on-disk content is read into the variable and then immediately written back to the same file. The write is a no-op (file already has correct content). A skip-write flag (`local _disk_rescued=false`) would make the intent explicit and avoid the redundant I/O, but the current behavior is harmless.
- `stages/plan_interview.sh:379` — after the guard fires, `success "DESIGN.md written"` is displayed even though the file was already on disk and wasn't actually overwritten. The message is slightly misleading; something like "DESIGN.md preserved from tool-written version" would be more accurate. Non-blocking.
- `stages/plan_generate.sh:87` / `stages/plan_interview.sh:351` — the 20-line threshold (`-gt 20`) is a bare magic number. Given it's used in two symmetrical locations, a named constant (e.g., `_MIN_SUBSTANTIVE_LINES=20`) would make it easier to adjust both if the heuristic needs tuning. Non-blocking.

## Coverage Gaps
- No test for the tool-write guard detection logic. A unit test (in `tests/`) that exercises the "captured output doesn't start with `#`, disk file does, and has >20 lines" branch and verifies that `design_content` is populated from disk would prevent regressions if the heuristic is changed. The guard is the core of this fix and is currently untested.

## Drift Observations
- None

---

## Review Notes

The fix is correct and complete for both stated symptom variants:

1. **Prompt directives** (`plan_interview.prompt.md:34`, `plan_generate.prompt.md:221`) — both synthesis prompts now have a first-rule "Do NOT use any tools to write files — the shell captures your text output and writes the file." directive. This is clear, prominent, and appropriately placed.

2. **Shell guards** — the detection heuristic is sound: if captured text doesn't start with `#` but the on-disk file does and has >20 lines, it's almost certainly a tool-write summary overwriting real content. The fix correctly rescues the on-disk version before the `printf` overwrite runs. The guard only fires when both conditions are true, so false positives (e.g., a legitimately non-heading-first document) would still need the on-disk file to look like a valid heading-started document with >20 lines to trigger rescue. Risk of false positive is negligible.

3. **Symmetry** — both `plan_interview.sh` and `plan_generate.sh` receive identical guard logic. `count_lines` usage follows the existing pattern in both files.
