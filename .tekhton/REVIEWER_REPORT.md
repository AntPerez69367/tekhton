# Reviewer Report

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `lib/common.sh` is 415 lines (pre-existing, not introduced by M120). Well over the 300-line ceiling; further extraction of logging/color/box-drawing helpers is pending its own milestone.
- In `_classify_project_maturity` (init_helpers_maturity.sh:26-27), the function checks for `.tekhton/DESIGN.md` and `DESIGN.md` on disk directly, duplicating the same checks the caller in `init.sh` (lines 225-229) already performs to build `_m120_design_file`. The redundancy is harmless and doesn't affect correctness, but the `$design_file` argument is redundant for the disk-file case.
- Suite 1 of `test_m84_static_analysis.sh` still excludes `common.sh` from literal-filename grep. Since M120 removed the literal assignments from `common.sh` (they now live exclusively in `artifact_defaults.sh`), the exclusion is technically unnecessary. Harmless, but the comment could mislead a future reader.

## Coverage Gaps
- None

## Drift Observations
- `lib/common.sh:1-17` — File has been over the 300-line ceiling since before M120 (415 lines after M120 reduced it from 446). The box-drawing helpers (_build_box_hline, _print_box_line, _setup_box_chars, _print_box_frame) are a natural extraction candidate for a future cleanup milestone.
- `lib/init_helpers_maturity.sh:26` and `lib/init.sh:225-229` — Redundant design-doc disk probes: the caller builds `_m120_design_file` by checking `.tekhton/DESIGN.md` and `DESIGN.md`, then passes it to `_classify_project_maturity`, which makes the same on-disk checks again internally. One of the two lookups is unnecessary.
