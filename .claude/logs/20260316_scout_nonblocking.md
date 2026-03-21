# Scout Report — NON_BLOCKING_LOG.md Implementation

## Summary
The NON_BLOCKING_LOG.md contains 11 open items accumulated from recent pipeline runs. These are low-priority technical debt and style fixes: test guards, portability improvements, design clarifications, and unused file cleanup. No new features or architectural changes required.

## Relevant Files

### Primary Targets
- **tests/test_config.sh** — Test guard issue where Test 2 calls `load_config()` twice without clearing variables between calls
- **lib/context.sh** — Multiple portability/style issues: gawk IGNORECASE extension, redundant export, missing local variable declaration, mixed bracket styles
- **lib/config.sh** — Missing clarifying comment for `TEST_CMD=true` default behavior
- **prompts/clarification.prompt.md** — Unused file created in prior milestone but never invoked

### Pattern Standardization Targets (wc -l | tr -d '[:space:]' pattern)
- **lib/agent_monitor.sh** — Used in activity detection
- **lib/agent.sh** — Used in context measurement
- **stages/cleanup.sh** — Used in batch counting
- **stages/plan_interview.sh** — Used in section counting
- **stages/plan_followup_interview.sh** — Used in incomplete section counting
- **tests/test_nonblocking_notes.sh** — Used in test assertions

### Related Files
- **lib/notes.sh** (line 207) — `select_cleanup_batch()` has cross-concern with CODER_SUMMARY.md reference; rest of module operates on HUMAN_NOTES.md without PROJECT_DIR prefix
- **lib/agent.sh** (lines 595, 615) — `find -maxdepth 4` hard-coded; could miss deeply nested project structures
- **lib/replan.sh** — At 293 lines (just under 300-line architectural limit); flagged for growth monitoring
- **stages/cleanup.sh** — Missing comment in `_parse_cleanup_report()` explaining intentional non-processing of "Not Attempted" section

## Key Symbols

### Functions Needing Fixes
- `load_config()` — lib/config.sh:line unknown
- `select_cleanup_batch()` — lib/notes.sh:line 207
- `_parse_cleanup_report()` — stages/cleanup.sh (needs comment)
- `_detect_file_changes()` — lib/agent.sh:line 595
- `_count_changed_files_since()` — lib/agent.sh:line 615
- `extract_relevant_sections()` — lib/context.sh:line 228-260 (gawk issue)

### Test Functions
- `test_config_handles_quoted_values()` — tests/test_config.sh (Test 2)

## Suspected Root Cause Areas

1. **Test isolation**: Test 2 in test_config.sh calls `load_config()` a second time without an `unset` guard like Test 1 uses, causing variable cross-contamination
2. **Portability gaps**: `wc -l` output contains leading whitespace on macOS/BSD — `tr -d '[:space:]'` works but inconsistent pattern application
3. **Design cross-concern**: `select_cleanup_batch()` in lib/notes.sh knows about CODER_SUMMARY.md (coder-stage artifact) while the rest of the module is isolated to HUMAN_NOTES.md management
4. **Context script fragility**: lib/context.sh uses gawk-specific `IGNORECASE` (line 229 comment claims portable but original code differs), redundant export assignment, and inconsistent shell conditional syntax
5. **Unused artifact**: prompts/clarification.prompt.md was created in Milestone 4 but main coder prompt already has `{{IF:CLARIFICATIONS_CONTENT}}` block — this file is never rendered
6. **Hard-coded limits**: `find -maxdepth 4` in agent monitoring could miss files in deeply nested structures (no escape path to configure depth)

## Complexity Estimate

Files to modify: 11
Estimated lines of change: 75
Interconnected systems: medium
Recommended coder turns: 30
Recommended reviewer turns: 8
Recommended tester turns: 20
