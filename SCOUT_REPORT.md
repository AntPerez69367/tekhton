# Scout Report: Milestone Shorthand Tasks

## Overview
Add support for milestone shorthand notation (e.g., "M66", "m3.1") in task strings for `--milestone`, `--complete`, and `--auto-advance` modes. Currently only the full "Milestone 66" format is accepted. The feature request seeks parity with the milestone ID shorthand used in `.claude/milestones/MANIFEST.cfg` (e.g., m01, m02, m03.1).

## Relevant Files
- tekhton.sh (line 1754) — Main milestone parsing from task string via regex. Currently matches `[Mm]ilestone[[:space:]]+([0-9]+([.][0-9]+)*)`, needs extension to also match `[Mm][0-9]+([.][0-9]+)*`
- lib/milestone_dag.sh (lines 216-247) — DAG ID conversion functions `dag_id_to_number()` and `dag_number_to_id()` that convert between manifest IDs (m01, m02, m03.1) and display numbers (1, 2, 3.1). These already support the parsing logic but handle m-prefixed IDs from the manifest, not shorthand in task strings.
- lib/milestones.sh (lines 15-72) — Milestone parsing from CLAUDE.md inline definitions. Uses regex at line 39 that matches milestone headings like `#### Milestone N: Title` or `#### [DONE] Milestone N: Title`. Does not parse task strings.
- HUMAN_NOTES.md — Contains the [FEAT] note indicating the feature request (status: [~] in-progress)

## Key Symbols
- `_CURRENT_MILESTONE` variable (tekhton.sh:1752) — Extracted milestone number from task string
- Regex pattern (tekhton.sh:1754) — The core pattern match that needs extension
- `dag_id_to_number()` (lib/milestone_dag.sh:216) — Utility that converts manifest IDs (m01) to numbers (1), shows the ID format already in use
- `dag_number_to_id()` (lib/milestone_dag.sh:226) — Reverse conversion, displays format expectations
- `parse_milestones()` (lib/milestones.sh:20) — Extracts numbered milestones from CLAUDE.md (not task parsing)

## Suspected Root Cause Areas
- tekhton.sh line 1754: Regex pattern only matches "Milestone N" literal, not "MN" shorthand. Needs to accept either format.
- No test coverage for shorthand parsing — tests exist for DAG conversions but not for task string shorthand extraction.

## Affected Test Files
- tests/test_orchestrate.sh — Tests orchestration state including MILESTONE_MODE and _CURRENT_MILESTONE, would benefit from shorthand format tests
- tests/test_find_next_milestone_dag.sh — Tests DAG frontier finding, could verify shorthand parsing before DAG fallback
- tests/test_milestone_split.sh — Tests milestone splitting with render_prompt, uses MILESTONE_MODE and could test parsing

## Complexity Estimate
Files to modify: 1
Estimated lines of change: 15
Interconnected systems: low
Recommended coder turns: 20
Recommended reviewer turns: 5
Recommended tester turns: 15

## Notes
- The change is localized to a single regex extension in tekhton.sh
- All downstream code (DAG resolution, commit signatures, state management) already works with numeric milestone numbers and requires no changes
- The feature piggybacks on existing `dag_number_to_id()` and `dag_id_to_number()` utility functions in the DAG module
- Supports both integer (M66) and decimal (M3.1) milestone numbers matching current syntax
- Case-insensitive like the existing pattern ([Mm]ilestone → [Mm] prefix support)
