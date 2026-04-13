# Drift Log

## Metadata
- Last audit: 2026-04-12
- Runs since audit: 3

## Unresolved Observations
- [2026-04-12 | "M76"] `lib/project_version_bump.sh:179,183` — The TOML handler (pyproject.toml / Cargo.toml) hardcodes double quotes in both pattern and replacement. The `setup.py` handler now correctly handles both quote styles via two separate patterns. The YAML handler (Chart.yaml, pubspec.yaml) does not use any quoting at all. The three strategies remain inconsistent in their quoting treatment — note for a future cleanup pass. (Carried from cycle 1.)

## Resolved
