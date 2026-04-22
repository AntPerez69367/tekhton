# Coder Summary

## Status: COMPLETE

## What Was Implemented

M120 — Planning Mode DESIGN_FILE Default Restoration. Four goals:

**Goal 1 — Stop `--init` from planting `DESIGN_FILE=""`.** In
`lib/init_config_sections.sh:_emit_section_essential`, the `else` branch
that emitted `DESIGN_FILE=""` now emits the canonical default
`DESIGN_FILE=".tekhton/DESIGN.md"` with an explanatory comment.

**Goal 2 — Restore defaults after `load_plan_config`.** Extracted the
artifact-path default block (`: "${VAR:=...}"` assignments) from
`lib/common.sh` into a new `lib/artifact_defaults.sh`. `common.sh` now
sources it in place of the inline block (zero behavior change).
`lib/plan.sh` sources it again immediately after `load_plan_config`, so
any artifact path that a pre-M120 `pipeline.conf` overwrote with an
empty string self-heals via `:=`. All three planning entry points
(`--plan`, `--replan`, `--plan-from-index`) share this code path.

**Goal 3 — Scope kept tight.** No changes to `config_defaults.sh`, the
config parser, or any consumer of `DESIGN_FILE`. Execution-pipeline
users with correct `pipeline.conf` files see no behavior change.

**Goal 4 — Context-aware end-of-init guidance.** Added
`_classify_project_maturity` and `_print_init_next_step` helpers in a
new `lib/init_helpers_maturity.sh` (extracted to keep `init_helpers.sh`
under 300 lines). `run_smart_init` now computes the project-maturity
classification (has_design | greenfield | brownfield) at the end and
prints the appropriate next-step hint: silent when a design doc exists,
a `--plan` push for greenfield, and a "Tekhton is ready" message for
brownfield that explicitly does not push `--plan`.

## Root Cause (bugs only)

Two compounding bugs:

1. `lib/init_config_sections.sh` emitted a literal `DESIGN_FILE=""` line
   when no design doc was detected at init time. This was a landmine in
   every fresh `pipeline.conf`.
2. `lib/plan.sh:load_plan_config` used `declare -gx "$_key=$_val"`,
   which blindly copies the empty string over the in-memory default
   installed by `common.sh`. Since planning mode deliberately bypasses
   `config_defaults.sh` (per the comment at `tekhton.sh:466-467`),
   nothing re-applied the default after the loader ran.

Downstream, `${PROJECT_DIR}/${DESIGN_FILE}` resolved to the project
directory itself. Writes to that path silently failed (redirection
failures don't abort functions under `set -euo pipefail`), and the
stage fabricated a fake success message.

## Files Modified

| File | Change |
|------|--------|
| `lib/artifact_defaults.sh` | **NEW.** Holds the `:=` default block for all Tekhton artifact paths. Idempotent, safe to source multiple times, no functions. |
| `lib/common.sh` | Replaced inline default block with `source artifact_defaults.sh`. Zero behavior change for existing callers. |
| `lib/plan.sh` | Added `source "${TEKHTON_HOME}/lib/artifact_defaults.sh"` immediately after `load_plan_config` to self-heal empty artifact paths written by older `pipeline.conf` files. |
| `lib/init_config_sections.sh` | Replaced `echo 'DESIGN_FILE=""'` with `echo 'DESIGN_FILE=".tekhton/DESIGN.md"'` plus explanatory comment lines. |
| `lib/init_helpers_maturity.sh` | **NEW.** Hosts `_classify_project_maturity` (pure classifier) and `_print_init_next_step` (branch-aware hint renderer). |
| `lib/init_helpers.sh` | Sources `init_helpers_maturity.sh`. |
| `lib/init.sh` | `run_smart_init` calls `_classify_project_maturity` and `_print_init_next_step` at the very end, after `emit_init_summary`. |
| `tests/test_init_design_file_autoset.sh` | Updated Test 2 to expect `DESIGN_FILE=".tekhton/DESIGN.md"` (new M120 default) instead of the empty-string landmine. |
| `tests/test_m84_static_analysis.sh` | Suite 1 excludes `artifact_defaults.sh` (now the authoritative location for artifact-path defaults, alongside `config_defaults.sh`). Suite 6 now checks `artifact_defaults.sh` for the `${TEKHTON_DIR}/` prefix rather than `common.sh`. |

## Human Notes Status

No unchecked human notes were listed in the task context.

## Docs Updated

None — no public-surface changes in this task. The only user-facing
touch is the new next-step hint text printed by `tekhton --init`, which
is not part of the documented CLI contract (it's narrative UX, and the
project has no doc page describing init's exact stdout). CLAUDE.md's
Documentation Responsibilities table does not cover terminal banner
copy.

## Observed Issues (out of scope)

- `lib/common.sh` is 415 lines (after my change reduced it from 446).
  It was already over the 300-line ceiling before M120. The milestone
  design explicitly prescribed only the surgical `source` replacement
  I made. Further extraction of logging/color/box-drawing helpers into
  separate files would be its own milestone.

## Scope Adherence Note

The active task was M120 only. M121 (write-failure hardening and
empty-slate integration tests) is a separately-scoped follow-up and
was left untouched per its own `Non-Goals` section in M120
("Assertions or early-abort behavior in plan-mode consumers when
DESIGN_FILE is empty... Covered by M121.").
