# Coder Summary
## Status: COMPLETE
## What Was Implemented
Milestone 76: Target-Project Version File Management — infrastructure for detecting,
parsing, and bumping version files in target projects during the finalize phase.

### Features Delivered
1. **Version file detection** — scans 10 ecosystems (package.json, pyproject.toml,
   Cargo.toml, setup.py, setup.cfg, gradle.properties, Chart.yaml, composer.json,
   pubspec.yaml, VERSION) and writes a config cache at `.claude/project_version.cfg`
2. **Version bump engine** — supports semver (major/minor/patch), calver (YYYY.MM.patch),
   datestamp (YYYY-MM-DD), and none strategies; disposition hints from CODER_SUMMARY.md
   (`## Breaking Changes` → major, `## New Public Surface` → minor, else → patch)
3. **Finalize hooks** — two hooks: `_hook_project_version_bump` (before commit) and
   `_hook_project_version_tag` (after commit); guarded by exit_code, strategy, and no-op gate
4. **User pre-bump detection** — if file version differs from cached version, skips
   automated bump and updates cache (respects manual version changes)
5. **Planning integration** — `## Versioning & Release Strategy` section added as
   REQUIRED to all 7 plan templates; interview prompts updated to probe for versioning
6. **Config defaults** — 7 new `PROJECT_VERSION_*` config keys with sensible defaults

## Root Cause (bugs only)
N/A — new feature implementation

## Files Modified

### New Files (6)
- `lib/project_version.sh` — version detection + config cache (180 lines)
- `lib/project_version_bump.sh` — bump logic + file writes (198 lines)
- `lib/finalize_version.sh` — finalize hook registration (65 lines)
- `tests/test_project_version_detect.sh` — detection tests (16 assertions)
- `tests/test_project_version_bump.sh` — bump tests (16 assertions)
- `tests/test_project_version_hint.sh` — disposition hint tests (6 assertions)

### Modified Files (15)
- `tekhton.sh` — version bump to 3.76.0, source new libs
- `lib/config_defaults.sh` — 7 new PROJECT_VERSION_* defaults
- `lib/finalize.sh` — source finalize_version.sh, register 2 hooks
- `templates/plans/web-app.md` — added Versioning & Release Strategy (REQUIRED)
- `templates/plans/api-service.md` — added Versioning & Release Strategy (REQUIRED)
- `templates/plans/mobile-app.md` — added Versioning & Release Strategy (REQUIRED)
- `templates/plans/web-game.md` — added Versioning & Release Strategy (REQUIRED)
- `templates/plans/custom.md` — added Versioning & Release Strategy (REQUIRED)
- `templates/plans/cli-tool.md` — renamed section, added REQUIRED marker
- `templates/plans/library.md` — added REQUIRED marker to existing section
- `prompts/plan_interview.prompt.md` — added versioning instruction #10
- `prompts/plan_interview_followup.prompt.md` — added versioning instruction #11
- `tests/test_finalize_run.sh` — updated hook count 21→23, position assertions
- `tests/test_plan_templates.sh` — updated EXPECTED_REQUIRED counts (+1 each)
- `tests/test_plan_docs_section.sh` — added Versioning section to fixture

### Docs Updated
- `CLAUDE.md` — 3 new lib files in repository layout, 6 new config variables in table

## Human Notes Status
No human notes to address.

## Rework (Senior Coder)

### Complex Blocker: setup.py quote-style mangling
- **Root cause:** `_bump_single_file` setup.py handler used `['\"]` to match the
  opening quote but hardcoded a single quote `'` in the replacement. Double-quoted
  `version="1.0.5"` was mangled to `version="1.0.6'` — broken Python syntax.
- **Fix:** Replaced the single sed pattern with two separate patterns: one for
  single-quoted values and one for double-quoted values, each preserving its own
  quote style.
- **File:** `lib/project_version_bump.sh:182-186`
- **Tests added:** Two new test cases in `tests/test_project_version_bump.sh` —
  single-quoted setup.py bump and double-quoted setup.py bump (18 assertions total,
  up from 16).

## Out-of-Scope Observations
- `lib/finalize.sh` and `lib/config_defaults.sh` are both over 300 lines (pre-existing)
- `tests/test_finalize_run.sh` has a pre-existing `HUMAN_NOTES_FILE: unbound variable`
  at line 114 that predates M76 changes (verified via git stash)
