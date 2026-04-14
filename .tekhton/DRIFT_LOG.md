# Drift Log

## Metadata
- Last audit: 2026-04-09
- Runs since audit: 4

## Unresolved Observations
- [2026-04-13 | "M82"] `lib/common.sh` has no `set -euo pipefail` (long-standing omission), while `finalize_display.sh`, `diagnose_output.sh`, `milestone_progress.sh`, and `milestone_progress_helpers.sh` all do. The codebase has split conventions for sourced lib files. A cleanup pass to align all lib files would resolve the inconsistency.
- [2026-04-12 | "M72"] `lib/prompts.sh:86` — The self-referential `${VAR:-${VAR}}` pattern is a common M72 migration mistake. A broader scan of other files changed in this milestone is worth doing to ensure this isn't replicated elsewhere — it was only found in prompts.sh.
- [2026-04-12 | "M72"] `tekhton.sh:106` — `ARCHITECT_PLAN.md` is still hardcoded (correct per spec — it is a single-run artifact not subject to migration), but the comment on that line says "archive it if it exists" without noting the `.tekhton/` context. No action needed; observation only.

## Resolved
