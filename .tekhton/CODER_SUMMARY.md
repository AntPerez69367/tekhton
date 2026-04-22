# Coder Summary

## Status: COMPLETE

## What Was Implemented

M113 — TUI Hierarchical Substage API.

Added the first half of the M113–M119 substage/lifecycle fix: a dormant API
for declaring a transient substage inside an already-open pipeline stage.
The API sets and clears substage globals, publishes them in `tui_status.json`,
and auto-closes with a single warn event if the parent stage ends while a
substage is still active. No caller is migrated in M113; the API is wired
into `lib/tui_ops.sh` (via `tui_stage_end` auto-close) and `lib/tui_helpers.sh`
(status JSON) but `stages/coder.sh`, `stages/review.sh`, and
`stages/architect.sh` remain byte-identical.

### Key design points

- **New file** `lib/tui_ops_substage.sh` — holds `tui_substage_begin`,
  `tui_substage_end`, and the `_tui_autoclose_substage_if_open` helper.
  Split out of `lib/tui_ops.sh` because that file was already at 297 lines;
  inlining the substage API would have crossed the 300-line ceiling. Sourced
  by `lib/tui.sh` immediately after `lib/tui_ops.sh`.
- **Parent-state preservation** — substage begin/end never touch
  `_TUI_CURRENT_STAGE_LABEL`, `_TUI_CURRENT_STAGE_START_TS`,
  `_TUI_CURRENT_LIFECYCLE_ID`, or `_TUI_STAGES_COMPLETE`. Verified by
  M113-2/M113-4 test assertions.
- **Auto-close in `tui_stage_end`** — call guarded with
  `declare -f _tui_autoclose_substage_if_open &>/dev/null && ...` so that
  callers (e.g. `tests/test_tui_stage_completion.sh`) that source only
  `lib/tui_ops.sh` without the substage companion continue to work.
- **Opt-out** — all substage behavior and the auto-close warning are gated
  on `TUI_LIFECYCLE_V2` (default `true`). Users who opted out of M110
  semantics see a pure no-op (M113-6a/b/c).
- **Status JSON** — two optional keys added:
  `current_substage_label` (string, `""` when idle) and
  `current_substage_start_ts` (int, `0` when idle). Always emitted; readers
  already tolerate extra keys.
- **Readability** — `_TUI_CURRENT_SUBSTAGE_LABEL` is a plain shell global,
  visible to `lib/common.sh` without re-sourcing `lib/tui_ops.sh`. Required
  by M117 (event attribution).

### Verification

- `bash tests/test_tui_substage_api.sh` — 20 passed, 0 failed.
- `bash tests/test_tui_stage_wiring.sh` — 53 passed, 0 failed (M110
  regression guard).
- `bash tests/test_tui_multipass_lifecycle.sh` — 7 passed, 0 failed (M111
  regression guard).
- `bash tests/test_tui_stage_completion.sh` — all passed (confirms
  substage auto-close helper does not regress parent timer computation).
- `shellcheck tekhton.sh lib/*.sh stages/*.sh tests/test_tui_substage_api.sh`
  — exit 0, zero warnings.
- File lengths: `lib/tui_ops.sh` 298, `lib/tui_helpers.sh` 229,
  `lib/tui.sh` 265, `lib/tui_ops_substage.sh` 62 — all under 300.

### Acceptance Criteria Mapping

| Criterion | Test |
|-----------|------|
| begin sets globals + writes status | M113-1a/1b/1c/1d |
| end clears globals, no stages_complete row | M113-3a/3b/3c |
| parent state untouched across cycle | M113-2a/2b/2c, M113-4 |
| auto-close + single warn on parent end | M113-5a/5b/5c |
| V2=false → both functions no-op | M113-6a/6b/6c |
| status JSON carries new keys when active, empty when idle | M113-1c/1d, M113-8a/8b |
| label externally readable without sourcing tui_ops.sh | M113-7 |
| no existing caller modified | git diff stages/ → empty |
| shellcheck clean | shellcheck exit 0 |
| new test covers full contract | tests/test_tui_substage_api.sh, 20 cases |

## Root Cause (bugs only)

N/A — feature task introducing dormant API infrastructure.

## Files Modified

- `lib/tui.sh` — added `_TUI_CURRENT_SUBSTAGE_LABEL` and
  `_TUI_CURRENT_SUBSTAGE_START_TS` globals; sourced
  `lib/tui_ops_substage.sh` after `lib/tui_ops.sh`.
- `lib/tui_ops.sh` — `tui_stage_end` now calls
  `_tui_autoclose_substage_if_open` when defined.
- `lib/tui_ops_substage.sh` (NEW) — substage API +
  `_tui_autoclose_substage_if_open` helper. 62 lines.
- `lib/tui_helpers.sh` — `_tui_json_build_status` now emits
  `current_substage_label` and `current_substage_start_ts`.
- `tests/test_tui_substage_api.sh` (NEW) — 8 test sections, 20
  assertions covering the M113 contract.
- `CLAUDE.md` — repository layout table lists
  `lib/tui_ops_substage.sh`.
- `ARCHITECTURE.md` — Layer 3 library catalog entry for
  `lib/tui_ops_substage.sh`.

## Human Notes Status

No human notes listed for this milestone.

## Docs Updated

- `CLAUDE.md` — repository layout table (project-facing structural doc).
- `ARCHITECTURE.md` — Layer 3 library catalog (architecture doc).

The Documentation Responsibilities section of CLAUDE.md treats the repo
layout and ARCHITECTURE.md library catalog as public-surface references;
new library files land in both.
