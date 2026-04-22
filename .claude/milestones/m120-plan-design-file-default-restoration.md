# M120 - Planning Mode DESIGN_FILE Default Restoration

<!-- milestone-meta
id: "120"
status: "pending"
-->

## Overview

Fresh projects created with `tekhton --init` ship with a time bomb in
`pipeline.conf`: when no design doc is detected at init time,
`lib/init_config_sections.sh:80` emits a literal `DESIGN_FILE=""` line.
The very next command most new users run is `tekhton --plan`, which
sources `lib/plan.sh`. That file auto-invokes `load_plan_config` (line
67), whose inline parser does `declare -gx "$_key=$_val"` (line 60) —
blindly copying the empty string over the in-memory default that
`lib/common.sh:14` installed seconds earlier.

`DESIGN_FILE` is then empty for the remainder of the planning run.
Everything downstream builds `"${PROJECT_DIR}/${DESIGN_FILE}"` → literal
`"${PROJECT_DIR}/"`, i.e. the project directory itself. The interview
tries to write the synthesized design with `printf ... > "$design_file"`,
the kernel returns "Is a directory", the error prints to stderr, and the
pipeline keeps running because the `>` redirection failure doesn't abort
a function under `set -euo pipefail`. The stage reports fake success:

```text
[✓]  written (exists (0 lines)).
[!] No  found — skipping completeness check.
```

Note the blank filenames — `${DESIGN_FILE}` is empty everywhere it's
interpolated. `PLAN_STATE.md` renders `-  (missing)` for the same reason.

The execution pipeline escapes this bug because `config_defaults.sh`
runs after `load_config` and re-applies the default with `:=` (which
handles empty strings). `--plan` mode deliberately skips
`config_defaults.sh` per the comment at `tekhton.sh:466-467` ("depends
on `_clamp_config_value`"). `--replan` (`tekhton.sh:489`) and
`--plan-from-index` (`tekhton.sh:538`) have the same shape and the same
bug.

M120 is the surgical root-cause fix: stop the landmine from being
planted, and ensure it can't detonate in any of the three planning-mode
entry points. M121 follows with defence-in-depth hardening and test
coverage.

Reported as GitHub issue #179.

## Design

### Goal 1 — Stop `--init` from planting `DESIGN_FILE=""`

`lib/init_config.sh:64-71` resolves `design_file` to an empty string
when none of `${DESIGN_FILE:-}`, `.tekhton/DESIGN.md`, or `DESIGN.md`
exist on disk at init time. `lib/init_config_sections.sh:77-81` then
emits:

```bash
if [[ -n "$design_file" ]]; then
    echo "DESIGN_FILE=\"${design_file}\""
else
    echo 'DESIGN_FILE=""'
fi
```

The `else` branch is the landmine. Two viable replacements:

1. **Omit the key entirely** when no design file is detected. Any
   downstream consumer falls back to the canonical default from
   `common.sh` / `config_defaults.sh` (`.tekhton/DESIGN.md`).

2. **Emit the canonical default** as a forward-looking placeholder:
   `DESIGN_FILE=".tekhton/DESIGN.md"` with a comment indicating this is
   where `--plan` will write.

**Selected: option 2.** Option 1 leaves users with an invisible
default and an unexplained gap in `pipeline.conf`'s "essential config"
section. Option 2 is explicit, matches what `--plan` will produce, and
requires zero behavior change elsewhere because the path it writes is
already the default.

Emission becomes:

```bash
# Where --plan will synthesize the design document (and where later
# stages will read it from). Leave as-is unless you already have one.
echo 'DESIGN_FILE=".tekhton/DESIGN.md"'
```

### Goal 2 — Restore defaults after `load_plan_config`

Even with Goal 1, pre-existing projects already have `DESIGN_FILE=""`
in their `pipeline.conf` files (they were `--init`'d before M120).
Goal 2 ensures the loader itself can't poison the variable.

Options evaluated:

1. **Make `load_plan_config` skip `declare -gx` when `_val` is empty.**
   Narrow but risky: if a user ever legitimately wants to clear a key
   in their config (not currently supported, but conceivable), this
   breaks that. Also requires the same change in `_parse_config_file`
   in `lib/config.sh`, since `load_plan_config` prefers that parser
   when it's available.

2. **Re-apply the artifact defaults after `load_plan_config` runs.**
   The defaults block in `common.sh:13-40` and `config_defaults.sh:64-85`
   uses `: "${VAR:=default}"`, which handles both unset and empty. Re-
   running it after the loader restores any key that was set to empty.

**Selected: option 2.** It's idempotent, contained, and matches the
pattern the non-plan pipeline already uses (`config_defaults.sh` runs
after `load_config`). No risk to external consumers.

Implementation: extract the `common.sh:13-40` artifact-default block
into a new `lib/artifact_defaults.sh` (header, `set -euo pipefail`, no
functions — just the `:=` lines). Source it from `common.sh` exactly
where that block lives today, so current behavior is preserved. Also
source it in `lib/plan.sh` immediately after `load_plan_config`
returns. All three planning-mode entry points (`--plan`, `--replan`,
`--plan-from-index`) share `lib/plan.sh`, so one source covers all of
them.

### Goal 3 — Keep the scope tight

No changes to:
- `config_defaults.sh` (non-plan path is unaffected by this bug).
- The config parser in `lib/config.sh` (the issue is absence of re-
  defaulting, not the parser semantics).
- Any consumer of `DESIGN_FILE` in `stages/` or elsewhere. The value
  arrives correct by the time any consumer runs.

No behavioral change to:
- Projects whose `pipeline.conf` has a non-empty `DESIGN_FILE=...` line
  (that value is preserved unchanged).
- Projects without a `pipeline.conf` at all (the `:=` defaults already
  covered this via `common.sh`).

The change is invisible to users whose configs are already correct and
is self-healing for users whose configs have the landmine.

## Files Modified

| File | Change |
|------|--------|
| `lib/artifact_defaults.sh` | **New file.** Contains the `:=` default block currently at `lib/common.sh:13-40`. Idempotent; safe to source multiple times. |
| `lib/common.sh` | Replace inline default block (lines 13-40) with `source "${TEKHTON_HOME:-$(dirname "${BASH_SOURCE[0]}")/..}/lib/artifact_defaults.sh"`. Zero behavior change for existing callers. |
| `lib/plan.sh` | Immediately after the `load_plan_config` call at line 67, source `lib/artifact_defaults.sh`. Re-defaults any artifact path that was overwritten with an empty string by pipeline.conf. |
| `lib/init_config_sections.sh` | In `_emit_section_essential` (lines 77-81), replace the `else` branch that emits `DESIGN_FILE=""` with `echo 'DESIGN_FILE=".tekhton/DESIGN.md"'`, plus a comment line explaining the placeholder. |

## Acceptance Criteria

- [ ] Running `tekhton --init` in a fresh temp directory with no
      pre-existing design doc produces a `pipeline.conf` whose
      `DESIGN_FILE` line is `DESIGN_FILE=".tekhton/DESIGN.md"` (not
      `DESIGN_FILE=""`).
- [ ] Running `tekhton --init` in a directory with an existing
      `DESIGN.md` at the root produces `DESIGN_FILE="DESIGN.md"` (current
      behavior, unchanged).
- [ ] Running `tekhton --init` in a directory with an existing
      `.tekhton/DESIGN.md` produces `DESIGN_FILE=".tekhton/DESIGN.md"`
      (current behavior, unchanged).
- [ ] Given a `pipeline.conf` that contains literal `DESIGN_FILE=""`
      (simulating a pre-M120 project), sourcing `lib/plan.sh` leaves
      `DESIGN_FILE` equal to `${TEKHTON_DIR}/DESIGN.md` — not empty.
      Verified with a unit test that sources `plan.sh` in a subshell
      with a crafted `pipeline.conf` and asserts the final value.
- [ ] Given a `pipeline.conf` that contains `DESIGN_FILE="custom.md"`,
      sourcing `lib/plan.sh` leaves `DESIGN_FILE="custom.md"` (user
      override survives).
- [ ] `lib/artifact_defaults.sh` exists and contains exactly the `:=`
      lines currently at `lib/common.sh:13-40`, plus the `set -euo
      pipefail` header. No functions. No side effects beyond variable
      assignment.
- [ ] Sourcing `lib/artifact_defaults.sh` twice in the same shell is
      safe (second source is a no-op because every variable is already
      set).
- [ ] `lib/common.sh` sources `lib/artifact_defaults.sh` in place of
      the inline block. Existing callers of `common.sh` see no change
      in `DESIGN_FILE`, `CODER_SUMMARY_FILE`, etc. values.
- [ ] End-to-end check: in a fresh temp directory, running
      `tekhton --init` followed by `tekhton --plan --answers <yaml>`
      produces a non-empty `.tekhton/DESIGN.md` on disk. (Requires a
      pre-built answers YAML fixture; reuse an existing one from the
      test suite.)
- [ ] Shellcheck clean for `lib/artifact_defaults.sh`, `lib/common.sh`,
      `lib/plan.sh`, `lib/init_config_sections.sh`.
- [ ] All existing tests continue to pass with no edits.

## Non-Goals

- Assertions or early-abort behavior in plan-mode consumers when
  `DESIGN_FILE` is empty or points to a directory. Covered by M121.
- Write-failure hardening in `stages/plan_interview.sh:195` (the
  `printf ... > "$design_file"` that silently fails). Covered by M121.
- A new integration test for the full `--init` → `--plan` empty-slate
  flow. Covered by M121.
- Changing `config_defaults.sh` or the non-plan config load path.
- Migrating existing user configs that contain `DESIGN_FILE=""`
  (Goal 2 makes them self-healing; no migration needed).
- Refactoring `load_plan_config` or `_parse_config_file` semantics.
- Supporting `DESIGN_FILE=""` as a user-intentional "disable" signal
  (not a current use case; if needed in future, a separate
  `DESIGN_FILE_ENABLED=false` flag would be the right shape).
