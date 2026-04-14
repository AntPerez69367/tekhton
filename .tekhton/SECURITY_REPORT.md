## Summary
M82 adds display-only CLI features: milestone progress rendering (`--milestones`), next-action guidance appended to finalization output, and a recovery command suggestion injected into the diagnose report. All changed code is purely presentational — no network I/O, no credential handling, no cryptography, and no `eval` or dynamic execution of attacker-controlled input. The two new library files are sourced shell scripts that read project state files and emit formatted text to stdout. The only concern is minor: `task` and `milestone` strings read verbatim from `PIPELINE_STATE.md` are embedded into a display-only command suggestion string without quote sanitization, which can produce a syntactically incorrect suggestion if those fields contain embedded double-quotes, but the output is never executed.

## Findings
- [LOW] [category:A03] [lib/milestone_progress.sh:159-165] fixable:yes — `_diagnose_recovery_command` embeds `$milestone` and `$task` read verbatim from `PIPELINE_STATE.md` into a quoted command string (`"${milestone}"`, `"${task}"`). If either field contains a double-quote character the displayed suggestion is syntactically broken. Since the output is only echoed (never `eval`'d) there is no injection risk, but the suggested command will be unusable. Fix: strip or escape embedded double-quotes before interpolation: `milestone="${milestone//\"/\\\"}"` and `task="${task//\"/\\\"}"`.

## Verdict
FINDINGS_PRESENT
