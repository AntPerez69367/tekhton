# Reviewer Report — M54: Auto-Remediation Engine

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `_route_to_human_action()` (error_patterns_remediation.sh:181–196) builds a multi-line `desc` variable but never passes it anywhere — only `oneline` reaches `append_human_action`. The `desc` block is dead code. Shellcheck may flag this as SC2034. Remove or use `desc` instead of `oneline` if richer output is intended.
- `error_patterns_remediation.sh` lands at 288 lines — 12 lines under the 300-line ceiling. Future additions should target a split before that limit is reached.
- ARCHITECTURE.md update (add `error_patterns_remediation.sh` and `gates_phases.sh` to the Library layer table) is called out in both ACPs as needed. This was not done as part of M54 — schedule for the next cleanup pass.

## Coverage Gaps
- None — test coverage for M54 assertions (safe exec, blocklist, max-attempts, dedup, code-skip, timeout, causal events, JSON log structure) is comprehensive. 38 new assertions across the remediation engine; all pass.

## ACP Verdicts
- ACP: Extract build gate phases to separate file — ACCEPT — gates.sh was approaching the 300-line ceiling; per-phase re-runability is a direct M54 requirement; backward-compatible (run_build_gate() behavior unchanged).
- ACP: New remediation engine file — ACCEPT — remediation logic (~250 lines) would have pushed error_patterns.sh over the ceiling; clean separation of classification (error_patterns.sh) from execution (error_patterns_remediation.sh); sourcing order in tekhton.sh is correct.

## Drift Observations
- `_gate_write_compile_errors` (gates_phases.sh:127–141) guards its classification block with `command -v annotate_build_errors`, but the body calls `classify_build_errors_all`. Both functions live in error_patterns.sh so the guard works, but the checked name and the called name differ — a reader would expect the guard to match the called function.
