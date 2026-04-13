# Drift Log

## Metadata
- Last audit: 2026-04-12
- Runs since audit: 4

## Unresolved Observations
- [2026-04-13 | "M77"] `lib/changelog.sh:172` — The zero-diff guard reads `git status --porcelain` to detect zero-diff runs, but at hook execution time, Tekhton's own pipeline artifacts (CODER_SUMMARY.md, REVIEWER_REPORT.md, etc.) are also uncommitted. A run that produced no project code changes but wrote pipeline artifacts would still pass this guard and emit a changelog entry. Low-impact for normal use, but worth revisiting if false-positive entries surface in practice.
- [2026-04-12 | "M76"] `lib/project_version_bump.sh:179,183` — The TOML handler (pyproject.toml / Cargo.toml) hardcodes double quotes in both pattern and replacement. The `setup.py` handler now correctly handles both quote styles via two separate patterns. The YAML handler (Chart.yaml, pubspec.yaml) does not use any quoting at all. The three strategies remain inconsistent in their quoting treatment — note for a future cleanup pass. (Carried from cycle 1.)

## Resolved
