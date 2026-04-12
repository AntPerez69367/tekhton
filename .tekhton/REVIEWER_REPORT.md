# Reviewer Report — M74: Documentation as a First-Class Pipeline Concern

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `lib/milestone_acceptance.sh:152` — The BRE `\|` alternation operator is GNU grep-only. On macOS/BSD grep, `\|` is treated as a literal backslash-pipe rather than alternation, so all three patterns collapse into one literal string that never matches. The DOCS_STRICT_MODE acceptance gate silently no-ops on macOS. Fix with `-E` for extended regex or split into three separate `grep` calls piped together. (Primary enforcement via reviewer blocker still works on all platforms — this is belt-and-suspenders.)
- `lib/milestone_acceptance.sh:152-153` — The grep patterns `'Docs Updated.*missing\|doc update.*missing\|documentation.*missing'` are narrow. A reviewer who writes "documentation not updated", "docs absent", or "## Docs Updated section not present" would not be caught. Since the primary enforcement path is the reviewer raising a Simple Blocker (triggering a rework cycle), this check is only a fallback for reviewer non-compliance with the strict mode instruction. Log as a cleanup item: broaden or document the expected reviewer phrasing to reduce false-negative risk.
- `prompts/reviewer.prompt.md:109-110` — First use of a nested `{{IF:VAR}}` conditional (DOCS_STRICT_MODE nested inside DOCS_ENFORCEMENT_ENABLED) in Tekhton prompt templates. CLAUDE.md documents the engine supports `{{IF:VAR}}...{{ENDIF:VAR}}` but does not document nesting. Since each pair uses a distinct variable name, a per-variable multi-pass processor would handle it correctly, but this assumption should be verified or noted in a comment.

## Coverage Gaps
- None

## Drift Observations
- None
