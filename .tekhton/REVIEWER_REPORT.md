# Reviewer Report — M76 Project Version Infrastructure (Re-review, Cycle 2)

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
None

## Simple Blockers (jr coder)
None

## Non-Blocking Notes
- `tests/test_project_version_detect.sh:158` — The pubspec.yaml assertion `grep -q 'CURRENT_VERSION=1.0.0'` is a substring match and passes falsely when the config contains `CURRENT_VERSION=1.0.0+1` (Flutter build number is not stripped during detection). Tighten to `grep -qE 'CURRENT_VERSION=1\.0\.0$'` to distinguish the two cases. (Carried from cycle 1 — still unaddressed, no blocker.)
- `lib/project_version.sh:88-99` — `path_key` (e.g. `.version`, `.project.version`) is written into `VERSION_FILES` in the config cache but is never consumed by the bump logic — `_bump_single_file` re-derives the accessor from the filename via `_accessor_for_file`, ignoring the stored path entirely. The key is vestigial as shipped. Either remove it from `VERSION_FILES` or add a comment explaining it is reserved for a future structured-read accessor. (Carried from cycle 1 — still unaddressed, no blocker.)
- `lib/finalize_version.sh:42-44` — `_hook_project_version_tag` accepts `exit_code` as a parameter (with `# shellcheck disable=SC2034`) but never checks it — the hook guards on `_COMMIT_SUCCEEDED` instead. The unused parameter is harmless and the disable comment is appropriate, but the asymmetry with `_hook_project_version_bump` (which does check `exit_code`) is mildly confusing. Consider either checking `exit_code` here for defense-in-depth or adding a comment explaining why it is deliberately ignored.

## Coverage Gaps
- `test_project_version_bump.sh` covers `package.json`, `VERSION`, `pyproject.toml`, `setup.py` (single and double quote), user-pre-bump, and `strategy=none`. No bump-write tests for `Cargo.toml`, `Chart.yaml`, `composer.json`, `setup.cfg`, `gradle.properties`, or `pubspec.yaml`. Consider adding `Cargo.toml` and `Chart.yaml` to exercise the toml/yaml sed patterns. (Carried from cycle 1.)

## Drift Observations
- `lib/project_version_bump.sh:179,183` — The TOML handler (pyproject.toml / Cargo.toml) hardcodes double quotes in both pattern and replacement. The `setup.py` handler now correctly handles both quote styles via two separate patterns. The YAML handler (Chart.yaml, pubspec.yaml) does not use any quoting at all. The three strategies remain inconsistent in their quoting treatment — note for a future cleanup pass. (Carried from cycle 1.)

---

## Prior Blocker Resolution

### Complex Blocker — setup.py quote-style mangling: FIXED
`lib/project_version_bump.sh:183-189` now uses two separate `sed` patterns — one for single-quoted values (`'`) and one for double-quoted values (`"`) — each back-referencing its own opening quote via `\1`. A file with `version="1.0.5"` now produces `version="1.0.6"` (not `version="1.0.6'`). Two new test cases in `tests/test_project_version_bump.sh` cover both quote styles.

### Simple Blocker — missing `set -euo pipefail`: FIXED
All three new library files now have `set -euo pipefail` on line 2:
- `lib/project_version.sh:2` ✓
- `lib/project_version_bump.sh:2` ✓
- `lib/finalize_version.sh:2` ✓
