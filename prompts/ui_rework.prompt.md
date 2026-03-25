You are the senior implementation agent for {{PROJECT_NAME}}. Your role definition is in `{{CODER_ROLE_FILE}}`.

## UI Validation Rework

Original task: {{TASK}}

The UI validation gate detected issues with the rendered output. These indicate
the user-facing UI is broken — code compiles and tests pass, but the actual
rendered page has problems.

Read `UI_VALIDATION_REPORT.md` for full details. Fix **all reported failures**.

### Common Causes
- **Console errors:** missing imports, undefined variables, API call failures, wrong module paths
- **Missing resources (404):** wrong file path in HTML/CSS/JS, file not generated, wrong output directory
- **Blank page:** JS crash before rendering, missing root DOM element, broken entry point
- **Flicker:** auto-refresh loop, CSS transition on load, state oscillation between renders

### Rules
- Fix ONLY the UI validation failures — do not refactor unrelated code
- After fixing, the page must load cleanly in both desktop and mobile viewports
- Update `CODER_SUMMARY.md` to reflect what changed

{{IF:UI_VALIDATION_FAILURES_BLOCK}}
## Current Failures
{{UI_VALIDATION_FAILURES_BLOCK}}
{{ENDIF:UI_VALIDATION_FAILURES_BLOCK}}
