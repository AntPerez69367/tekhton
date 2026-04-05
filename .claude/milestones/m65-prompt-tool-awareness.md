# Milestone 65: Prompt Tool Awareness — Serena & Repo Map Coverage
<!-- milestone-meta
id: "65"
status: "pending"
-->

## Overview

An audit of all 22 prompt templates found that only 3 (scout, coder, reviewer)
have explicit instructions to use Serena MCP tools and prefer them over grep/find.
The remaining 17 prompts — including high-impact ones like tester, coder_rework,
build_fix, and all specialists — have zero tool guidance. Agents in these roles
have Serena tools available via `--mcp-config` but don't know to use them, causing
fallback to manual grep/find that wastes turns and time.

This milestone adds Serena and repo map guidance to all prompts where agents do
code discovery or modification.

Depends on M61 (Repo Map Cache) so cached maps are available without regeneration
cost, and M56 for stable baseline.

## Scope

### 1. High-Impact Prompts (Code-Changing Agents)

**Tier 1 — agents that write/modify code and need file discovery:**

**`prompts/tester.prompt.md`:**
- Add `{{IF:SERENA_ACTIVE}}` block with `find_symbol` / `get_symbol_definition`
  guidance for reading source class signatures before writing tests
- Strengthen repo map section: "Use the repo map as your primary source for
  identifying test targets. Do NOT grep for class definitions."
- Highest impact: tester reads source files for every test it writes

**`prompts/coder_rework.prompt.md`:**
- Add `{{IF:SERENA_ACTIVE}}` block and `{{IF:REPO_MAP_CONTENT}}` block
- Rework agents fix review blockers that reference specific functions — Serena's
  `find_symbol` eliminates grep-based discovery

**`prompts/build_fix.prompt.md`:**
- Add `{{IF:SERENA_ACTIVE}}` block for resolving import/reference errors
- Build fix agents often need to find the correct import path or verify a symbol
  exists — `find_symbol` is exactly the right tool

**`prompts/tester_resume.prompt.md`:**
- Add brief `{{IF:SERENA_ACTIVE}}` block (lighter than full tester prompt since
  agent already has context from initial invocation)

### 2. Medium-Impact Prompts (Code-Analyzing Agents)

**Tier 2 — agents that analyze code and verify cross-references:**

**`prompts/architect.prompt.md`:**
- Add `{{IF:SERENA_ACTIVE}}` block — drift analysis benefits from
  `find_referencing_symbols` to verify caller/callee relationships

**`prompts/specialist_security.prompt.md`:**
- Add `{{IF:SERENA_ACTIVE}}` block — security review should use
  `find_referencing_symbols` to trace data flow through auth/input handlers

**`prompts/specialist_performance.prompt.md`:**
- Add `{{IF:SERENA_ACTIVE}}` block — performance review benefits from
  `find_referencing_symbols` to identify hot-path callers

**`prompts/specialist_api.prompt.md`:**
- Add `{{IF:SERENA_ACTIVE}}` block — API review should verify contract
  consistency across endpoints using `find_symbol`

### 3. Lower-Impact Prompts (Targeted Agents)

**Tier 3 — short-lived agents with narrow scope:**

**`prompts/jr_coder.prompt.md`:**
- Add brief `{{IF:SERENA_ACTIVE}}` note (jr coder fixes specific files, but
  may need to verify signatures)

**`prompts/architect_sr_rework.prompt.md`** and **`prompts/architect_jr_rework.prompt.md`:**
- Add brief `{{IF:SERENA_ACTIVE}}` notes for rework file discovery

**`prompts/build_fix_minimal.prompt.md`:**
- Add one-line `{{IF:SERENA_ACTIVE}}` note (minimal prompt, minimal addition)

### 4. Standardized Guidance Block

**File:** `prompts/` (pattern for all additions)

Use a standardized phrasing across all prompts for consistency:

```markdown
{{IF:SERENA_ACTIVE}}
## LSP Tools Available
You have LSP tools via MCP: `find_symbol`, `find_referencing_symbols`,
`get_symbol_definition`. These provide exact cross-reference data.
**Prefer LSP tools over grep/find for symbol lookup.**
{{ENDIF:SERENA_ACTIVE}}
```

Prompts in Tier 1 get expanded versions with role-specific examples. Tiers 2-3
get the standard block above.

### 5. Repo Map Preference Language

For prompts that have `{{IF:REPO_MAP_CONTENT}}` but lack preference instructions,
add explicit guidance:

```markdown
Use the repo map as your primary file discovery source. Do NOT use `find` or
`grep` for broad file discovery — the repo map has already done that work.
```

Apply to: `tester.prompt.md`, `architect.prompt.md` (already has map, needs
stronger language).

## Migration Impact

No new config keys. All additions are inside `{{IF:...}}` conditional blocks —
zero impact when Serena or repo map are disabled.

## Acceptance Criteria

- All Tier 1 prompts have Serena + repo map guidance with role-specific examples
- All Tier 2 prompts have standard Serena guidance block
- All Tier 3 prompts have brief Serena notes
- No prompt has contradictory "use grep to find" instructions
- All `{{IF:SERENA_ACTIVE}}` blocks render correctly (test with SERENA_ACTIVE=""
  and SERENA_ACTIVE="true")
- All `{{IF:REPO_MAP_CONTENT}}` blocks include preference language
- All existing tests pass
- All new/modified prompts pass `bash -n` validation (no template syntax errors)

Tests:
- Render each modified prompt with SERENA_ACTIVE=true — verify block appears
- Render each modified prompt with SERENA_ACTIVE="" — verify block is absent
- Render tester prompt with REPO_MAP_CONTENT populated — verify preference text
- Verify no prompt contains "use grep" or "use find" without a Serena alternative

Watch For:
- Prompt size inflation: each Serena block adds ~100-150 tokens. For the tester
  (which already has the longest prompt), verify total stays within context budget.
  Use `_add_context_component` to track.
- Don't over-instruct: the standard block should be brief. Claude already knows
  how to use MCP tools — the prompt just needs to say "prefer them."
- Conditional blocks must handle the case where Serena is available but the MCP
  server failed to start (SERENA_ACTIVE="" even though SERENA_ENABLED=true).

Seeds Forward:
- Tool-aware agents should show reduced grep/find usage in future runs
- M62 timing data can measure before/after impact on tester stage duration
