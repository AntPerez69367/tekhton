# Coder Summary

## Status: COMPLETE

## What Was Implemented
Addressed all 6 open non-blocking notes from `.tekhton/NON_BLOCKING_LOG.md`.

1. **Serena log collision** (`lib/init_wizard.sh:208–219`): `setup_serena.sh` now
   writes to `logs/serena_setup.log` instead of sharing `indexer_setup.log` with
   `setup_indexer.sh`. Indexer failure output is no longer overwritten by the
   subsequent Serena run.

2. **Redundant `return $?`** (`lib/init_wizard.sh:175–177`): Replaced `return $?`
   with bare `return` in the VERBOSE branch of `_wizard_run_setup_script`. `return`
   without an argument already propagates the last command's exit status.

3. **Cross-module array mutation** (`lib/init_wizard.sh:224`): `_run_wizard_venv_setup`
   no longer writes to `_INIT_FILES_WRITTEN` directly. It now exports
   `_WIZARD_VENV_CREATED=true` after a venv setup attempt, and `lib/init.sh`
   appends to its own `_INIT_FILES_WRITTEN` array based on that signal. Ownership
   of the bookkeeping array stays in `init.sh`. Also added `_WIZARD_VENV_CREATED`
   to `_wizard_reset_state` so repeated calls start clean.

4. **Mid-file import** (`tools/tests/test_tui.py:774`): Hoisted
   `import time as _time` to the module-level import block. The `# noqa: E402`
   suppression is no longer needed and was removed. The three function-local
   `import time as time_mod` statements are pre-existing and out of scope.

5. **TUI pill flash on resume** (`tekhton.sh`): Wrapped the `tui_stage_begin` and
   `tui_stage_end` calls in `should_run_stage` guards. On `--start-at review`,
   upstream pills (coder, docs, security) no longer flash active→complete with
   0/0 turns; they remain in their pre-run state instead. The paired
   `_tui_will_run_stage` variable tracks the guard so `tui_stage_end` only fires
   for stages whose `tui_stage_begin` actually ran.

6. **Stage label fallback divergence** (`lib/pipeline_order.sh`):
   `get_display_stage_order` now routes every stage name through
   `get_stage_display_label` instead of duplicating the mapping inline. Pill-row
   output and `tui_stage_begin/end` call sites now share a single canonical label
   registry — a new stage added only to the pipeline order will still produce
   matching labels via the shared fallback. The comment on the fallback in
   `get_stage_display_label` was updated to reflect the new single-source-of-truth.

## Root Cause (bugs only)
Not bug fixes — all six were non-blocking code-quality improvements flagged by
reviewers in prior milestone runs (M106–M109).

## Files Modified
- `lib/init_wizard.sh` — Notes 1, 2, 3: serena log separation, bare `return`,
  `_WIZARD_VENV_CREATED` signal
- `lib/init.sh` — Note 3: append to `_INIT_FILES_WRITTEN` when
  `_WIZARD_VENV_CREATED=true`
- `tools/tests/test_tui.py` — Note 4: hoisted `import time as _time` to top of
  file, removed mid-file import and `# noqa: E402`
- `tekhton.sh` — Note 5: `tui_stage_begin`/`tui_stage_end` gated on
  `should_run_stage` via `_tui_will_run_stage` local
- `lib/pipeline_order.sh` — Note 6: `get_display_stage_order` delegates label
  mapping to `get_stage_display_label`; updated fallback comment

## Docs Updated
None — no public-surface changes in this task. All edits are internal
refactors to existing private functions (`_run_wizard_venv_setup`,
`_wizard_run_setup_script`, `get_display_stage_order`) or minor code-hygiene
fixes in tests and the pipeline loop. No CLI flags, config keys, or template
variables changed.

## Human Notes Status
- Note 1 (`lib/init_wizard.sh:208–219` serena log collision): COMPLETED
- Note 2 (`lib/init_wizard.sh:175–177` redundant `return $?`): COMPLETED
- Note 3 (`lib/init_wizard.sh:224` cross-module array mutation): COMPLETED
- Note 4 (`tools/tests/test_tui.py:774` mid-file import): COMPLETED
- Note 5 (`tui_stage_begin` called before `should_run_stage` check): COMPLETED
- Note 6 (`get_stage_display_label` vs `get_display_stage_order` fallback): COMPLETED

## Validation
- `shellcheck tekhton.sh lib/init_wizard.sh lib/init.sh lib/pipeline_order.sh`
  passes with only pre-existing SC1091 info messages (sourcing external files)
  and one pre-existing SC2086 info on unrelated lines.
- `bash tests/run_tests.sh`: 410 shell tests pass, 151 Python tests pass.
