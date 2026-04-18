# M99 — Output Bus: Unified CLI/TUI Layer

## Problem Statement

Tekhton's user-facing output is spread across 13+ files (3,584 lines), with 91
direct `echo -e` calls using ANSI color variables outside `common.sh` across 10
files. The TUI sidecar introduced in M97–M98 bolted a JSON-status-file–based
rendering layer on top of the existing CLI output, but the two systems operate
as parallel channels rather than a unified bus. This produces a class of bugs
that are expensive to diagnose because each bug crosses 3–5 files:

**Symptoms observed (April 2026):**
- TUI header showed `complete · Pass 1/5` instead of `fix-nb · Pass 1/1`
  because `FIX_NONBLOCKERS_MODE` sets `COMPLETE_MODE=true` for the orchestration
  loop, and run-mode detection ran in wrong priority order.
- Task string in events panel contained literal `\033[1m` because `BOLD` uses
  single-quoted shell notation and `_tui_strip_ansi` only matched ESC bytes.
- Attempt counter always shows `1` because `PIPELINE_ATTEMPT` is never set
  anywhere — the actual counter is `_ORCH_ATTEMPT` in `orchestrate.sh`.

**Root causes (architectural):**

1. **No single source of truth for run context.** Mode flags, attempt counters,
   stage order, and task description are set in scattered locations across
   `tekhton.sh`, `orchestrate.sh`, and the fix-loop functions. The TUI reads
   them opportunistically from globals, creating invisible coupling.

2. **Two uncoordinated output channels.** `log()`/`warn()`/etc. write to
   terminal (CLI mode) or forward to TUI events (TUI mode), but 10 files
   bypass this entirely with direct `echo -e`. The finalize banner prints
   to stdout while the TUI owns the alternate screen buffer.

3. **Stage order hardcoded in 3 places.** `tekhton.sh` line ~1900 hardcodes
   `intake scout coder security review tester`, `tui.py` has its own fallback,
   and `pipeline_order.sh` computes the real order dynamically. Docs stage,
   test-first order, and skipped stages aren't reflected.

4. **Four parallel attempt counters, none synced to TUI.** `_ORCH_ATTEMPT`,
   `human_attempt`, `nb_attempt`, `drift_attempt` — each local to its loop,
   each invisible to the TUI which reads the nonexistent `PIPELINE_ATTEMPT`.

## Design Principle

Introduce an **output bus** — a thin abstraction layer that is the single gateway
for all user-facing output. Every piece of information that reaches the user's
eyes (CLI text, TUI header, TUI events, log file) flows through the bus. The bus
owns:

- **Run context**: mode, attempt, stage order, task, milestone, flags
- **Output routing**: CLI echo vs TUI event vs log file vs all three
- **Formatting**: ANSI for CLI, plain text for log/TUI, structured for JSON
- **Lifecycle**: startup banner, stage transitions, completion banner

The bus is **not** a framework rewrite. It is a refactoring of existing concerns
into a cohesive module with a clear API, implemented as 2–3 shell library files
that replace the scattered output logic.

## Architecture

### The Output Bus (`lib/output.sh`)

```
┌─────────────────────────────────────────────────┐
│                   Callers                        │
│  (tekhton.sh, stages/*.sh, lib/*.sh)             │
│                                                  │
│  out_log MSG          out_stage_start N LABEL    │
│  out_warn MSG         out_stage_finish VERDICT   │
│  out_error MSG        out_banner SECTIONS...     │
│  out_success MSG      out_set_context KEY=VALUE  │
│  out_header MSG       out_complete VERDICT       │
└──────────────────────┬──────────────────────────┘
                       │
           ┌───────────▼───────────┐
           │     Output Bus        │
           │   (lib/output.sh)     │
           │                       │
           │  _OUT_CONTEXT{}       │
           │    .mode              │
           │    .attempt           │
           │    .max_attempts      │
           │    .task              │
           │    .milestone         │
           │    .milestone_title   │
           │    .stage_order[]     │
           │    .cli_flags         │
           │    .current_stage     │
           │    .current_model     │
           │                       │
           │  Routes:              │
           │  ├─ CLI (echo -e)     │
           │  ├─ TUI (JSON status) │
           │  └─ Log file          │
           └───────────────────────┘
```

### Key design decisions

1. **Associative array for run context.** A single `declare -A _OUT_CTX` holds
   all run-state that affects display. Any code that changes run state calls
   `out_set_context key value`. The TUI JSON builder reads exclusively from
   `_OUT_CTX` — no more scattered global reads.

2. **All output functions route through `_out_emit`.** The core emit function
   decides per-call whether to write to terminal, log file, TUI events, or all
   three, based on `_TUI_ACTIVE`, verbosity level, and caller-specified channel.

3. **Banner/section output uses structured calls.** Instead of 10 files each
   doing their own `echo -e "${BOLD}..."` banner formatting, they call
   `out_banner` or `out_section` with structured data. The bus formats
   appropriately for CLI (ANSI boxes) or TUI (event feed + structured fields).

4. **Stage order derived once, stored in context.** `out_set_context stage_order`
   is called after `get_pipeline_order()` returns, and the TUI reads from
   `_OUT_CTX[stage_order]` — no hardcoding.

5. **Backward compatible.** `log()`, `warn()`, `error()`, `success()`, `header()`
   remain as thin wrappers that call `_out_emit`. Existing callers don't change
   unless they're doing direct `echo -e` with ANSI.

### File structure

| File | Role | Replaces |
|------|------|----------|
| `lib/output.sh` | Bus core: context store, emit routing, ANSI strip | Output parts of `lib/common.sh` |
| `lib/output_format.sh` | CLI formatting: banners, boxes, progress bars, tables | `lib/finalize_display.sh`, display parts of `lib/diagnose_output.sh`, `lib/report.sh`, `lib/init_report_banner.sh`, `lib/milestone_progress_helpers.sh` |
| `lib/output_tui.sh` | TUI bridge: JSON builder, sidecar lifecycle, state sync | `lib/tui.sh`, `lib/tui_helpers.sh` |

The Python sidecar (`tools/tui.py`, `tools/tui_render.py`, `tools/tui_hold.py`)
stays as-is — it's already well-structured and only consumes JSON. The shell-side
JSON builder just moves into `lib/output_tui.sh`.

## What Changes for Callers

### Before (current)

```bash
# In tekhton.sh — run mode detection
_tui_run_mode="task"
[[ "$MILESTONE_MODE" = true ]] && _tui_run_mode="milestone"
[[ "$FIX_NONBLOCKERS_MODE" = true ]] && _tui_run_mode="fix-nb"
...
tui_set_context "$_tui_run_mode" "$_tui_cli_flags" intake scout coder security review tester

# In orchestrate.sh — attempt tracking
_ORCH_ATTEMPT=$(( _ORCH_ATTEMPT + 1 ))
# (TUI never sees this)

# In finalize_display.sh — direct ANSI
echo -e "${BOLD}${CYAN}══════════════════════════════════════${NC}"
echo -e "  Task:      ${BOLD}${TASK}${NC}"
```

### After (with output bus)

```bash
# In tekhton.sh — set context once
out_set_context mode "fix-nb"
out_set_context task "$TASK"
out_set_context stage_order "$(get_pipeline_order)"

# In orchestrate.sh — attempt tracking synced automatically
out_set_context attempt "$_ORCH_ATTEMPT"
out_set_context max_attempts "${MAX_PIPELINE_ATTEMPTS:-5}"

# In finalize_display.sh — structured
out_banner "Tekhton — Pipeline Complete" \
    "Task|$(out_ctx task)" \
    "Verdict|${verdict}" \
    "Duration|$(out_ctx duration)"
```

## Acceptance Criteria

1. All user-facing output (terminal text, TUI events, log file) flows through
   `lib/output.sh` — no direct `echo -e` with ANSI color variables outside the
   output module.

2. Run context (mode, attempt, stage order, task, flags) is stored in `_OUT_CTX`
   and updated via `out_set_context`. The TUI JSON builder reads exclusively from
   `_OUT_CTX`.

3. TUI header displays correct run mode, attempt counter, and stage order for all
   execution modes: `--fix nb`, `--fix drift`, `--human`, `--complete`,
   `--milestone`, plain task.

4. Finalize/completion banners render correctly in both CLI and TUI modes without
   overlapping the alternate screen buffer.

5. `shellcheck` clean. All existing tests pass. No regressions in CLI output for
   non-TUI users.

6. Direct `echo -e` with `${BOLD}`, `${RED}`, etc. outside `lib/output*.sh` is
   reduced to zero (enforced by a grep-based lint check in tests).

## Milestone Breakdown

This is too large for a single milestone. Breaking into focused, independently
shippable milestones:

---

### M99 — Output Bus Core + Context Store

**Scope:** Create `lib/output.sh` with the `_OUT_CTX` associative array, the
`out_set_context` / `out_ctx` API, and the `_out_emit` routing core. Migrate
`log()`, `warn()`, `error()`, `success()`, `header()`, `mode_info()` from
`common.sh` into thin wrappers that call `_out_emit`. Wire `out_set_context`
calls at the 4 context-setting sites in `tekhton.sh` (mode, task, stage order,
flags) and the attempt-counter sites in `orchestrate.sh` / fix loops.

**Changes:**
- New: `lib/output.sh` (~200 lines)
- Edit: `lib/common.sh` — move output functions to wrappers
- Edit: `tekhton.sh` — replace `_tui_run_mode` derivation with `out_set_context`
- Edit: `lib/orchestrate.sh` — add `out_set_context attempt` on increment
- Edit: `tekhton.sh` fix-nb / fix-drift / human loops — sync attempt counter
- Edit: `lib/tui_helpers.sh` — read from `_OUT_CTX` instead of scattered globals

**Acceptance:** TUI shows correct mode, attempt, task for all execution modes.
`PIPELINE_ATTEMPT` global eliminated. No behavioral change to CLI output.

**Depends on:** None (this is the foundation)

---

### M100 — Dynamic Stage Order + TUI Sync

**Scope:** Replace hardcoded stage lists with dynamic derivation. The output bus
stores the actual pipeline stage order (computed by `get_pipeline_order()`) and
the TUI reads it from context rather than from a hardcoded argument.

**Changes:**
- Edit: `tekhton.sh` — call `out_set_context stage_order` from `_run_pipeline_stages`
- Edit: `lib/output_tui.sh` (or `lib/tui_helpers.sh`) — read stage order from `_OUT_CTX`
- Edit: `tools/tui.py` — remove hardcoded fallback stage list
- Edit: `lib/pipeline_order.sh` — integrate stage skip logic (security disabled,
  intake disabled, docs enabled) into the order before it reaches the bus
- Add: test that verifies TUI JSON stage_order matches `get_pipeline_order()` output

**Acceptance:** `--skip-security`, `DOCS_AGENT_ENABLED=true`, `PIPELINE_ORDER=test_first`
all produce correct TUI stage pills. No hardcoded stage lists remain.

**Depends on:** M99

---

### M101 — Eliminate Direct ANSI Output

**Scope:** Migrate all 91 direct `echo -e` ANSI calls across 10 files to use
output bus functions. Create `lib/output_format.sh` with structured formatters
for banners, boxed sections, key-value tables, and progress indicators.

**Target files (10):**
- `lib/finalize.sh` — completion banner
- `lib/finalize_display.sh` — action items
- `lib/diagnose_output.sh` — diagnosis report
- `lib/report.sh` — run report
- `lib/init_report_banner.sh` — init summary
- `lib/init_helpers.sh` — init progress
- `lib/milestone_progress_helpers.sh` — progress bars
- `lib/artifact_handler.sh` — artifact notices
- `lib/clarify.sh` — clarification prompts
- `lib/diagnose.sh` — diagnostic headers

**Changes:**
- New: `lib/output_format.sh` (~250 lines) — formatters for structured display
- Edit: all 10 files above — replace direct ANSI with formatter calls
- Add: grep-based lint test ensuring no `echo -e.*\${BOLD\|RED\|GREEN...}` outside
  `lib/output*.sh`

**Acceptance:** Lint check passes. All banners/reports render correctly in both
CLI and TUI modes. NO_COLOR support preserved.

**Depends on:** M99

---

### M102 — TUI-Aware Finalize + Completion Flow

**Scope:** Fix the completion-banner–vs–TUI conflict. When TUI is active, the
finalize banner content is routed to TUI events and/or held until after
`tui_complete()` tears down the alternate screen. Action items are surfaced in
the TUI hold-on-complete screen.

**Changes:**
- Edit: `lib/finalize.sh` — guard banner output with `_out_emit` routing
- Edit: `tools/tui_hold.py` — accept and render action items from status JSON
- Edit: `lib/output_tui.sh` — add action_items to JSON status (currently always `[]`)
- Edit: `lib/finalize_display.sh` — emit action items as structured data

**Acceptance:** No output artifacts when TUI is active during finalization.
Action items visible in TUI hold-on-complete screen. CLI-only mode unchanged.

**Depends on:** M101

---

### M103 — Output Bus Tests + Integration Validation

**Scope:** Comprehensive test suite for the output bus. Unit tests for context
management, emit routing, ANSI stripping. Integration tests that verify TUI JSON
correctness across all execution modes.

**Changes:**
- New: `tests/test_output_bus.sh` — unit tests for `_OUT_CTX`, `_out_emit`,
  routing logic, ANSI strip
- New: `tests/test_output_tui_sync.sh` — verify TUI JSON fields match actual
  run context for each mode (fix-nb, fix-drift, human, complete, milestone, task)
- New: `tests/test_output_lint.sh` — the `echo -e` ANSI lint check
- Edit: existing TUI tests — update to use output bus context

**Acceptance:** All new tests pass. Lint check enforced in CI. No regressions.

**Depends on:** M102

## Implementation Order

```
M99 (core + context) ─────► M100 (stage order sync)
         │                           │
         └──► M101 (ANSI migration) ─┤
                                     │
                                     ▼
                              M102 (finalize flow)
                                     │
                                     ▼
                              M103 (tests + lint)
```

M99 is the foundation that unblocks both M100 and M101 in parallel. M102 depends
on the format functions from M101. M103 is the capstone that enforces the new
architecture.

## Risk Assessment

- **Scope creep:** M101 touches 10 files with 91 echo calls. Each is small but
  the total surface is large. Mitigated by: each file is independently testable;
  the lint check catches regressions immediately.

- **Backward compatibility:** `log()`, `warn()`, etc. remain as the public API.
  Only the internal routing changes. Scripts that source `common.sh` keep working.

- **TUI sidecar stability:** The Python side doesn't change (except removing a
  hardcoded fallback). Risk is low.

- **Shell limitations:** Associative arrays require bash 4.0+ (Tekhton already
  requires 4.3+). No new dependency.

## What This Does NOT Cover

- Rewriting the TUI sidecar in a different language (see DESIGN_v5.md)
- Adding new TUI panels or interactive controls (V4 scope)
- Provider-neutral output formatting (V4 multi-provider scope)
- Structured logging for enterprise (V4 enterprise scope)

These are explicitly out of scope. The output bus creates the foundation that
makes those future changes easier, but does not implement them.
