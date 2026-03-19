# Drift Log

## Metadata
- Last audit: 2026-03-19
- Runs since audit: 1

## Unresolved Observations
- [2026-03-19 | "architect audit"] **Observation 2 — agent_monitor.sh coordination note (Milestone 14):**
- [2026-03-19 | "architect audit"] The observation itself states "final state is correct" and "not a process concern."
- [2026-03-19 | "architect audit"] No action warranted.
- [2026-03-19 | "architect audit"] **Observation 3 — `stages/tester.sh:101` grep|tee duplicate log entries:**
- [2026-03-19 | "architect audit"] The `grep ... | tee -a "$LOG_FILE"` pattern does not exist in `stages/tester.sh`.
- [2026-03-19 | "architect audit"] Line 101 is inside a heredoc (`## Test Summary`). The only grep uses referencing
- [2026-03-19 | "architect audit"] `$LOG_FILE` are read-only (`grep -q ... "$LOG_FILE"` at lines 120, 134) — they
- [2026-03-19 | "architect audit"] read from the log, not write to it. The original observation does not match the
- [2026-03-19 | "architect audit"] current code. Stale.
- [2026-03-19 | "architect audit"] **Observation 4 — `lib/config.sh` 342 lines:**
- [2026-03-19 | "architect audit"] Current line count is 170. The extraction of `lib/config_defaults.sh` already
- [2026-03-19 | "architect audit"] resolved this. Resolved.
- [2026-03-19 | "architect audit"] **Observation 5 — `lib/agent_monitor.sh` over 300 lines:**
- [2026-03-19 | "architect audit"] Current line count is 286 — under the 300-line ceiling. Resolved.
- [2026-03-19 | "architect audit"] **Observation 6 — `lib/agent_monitor.sh:211` kill comment:**
- [2026-03-19 | "architect audit"] The explanatory comment already exists at line 165: "This subshell cannot reach
- [2026-03-19 | "architect audit"] the outer `_run_agent_abort` trap — kill directly." Resolved.
- [2026-03-19 | "architect audit"] **Observation 7 — `lib/common.sh:61-65` `_print_box_line` fallback rendering:**
- [2026-03-19 | "architect audit"] The observation mischaracterizes the fallback. The empty branch fallback (line 65)
- [2026-03-19 | "architect audit"] is `echo "${_bv}$(_build_box_hline "$_bw" " ")${_bv}"` — it correctly includes
- [2026-03-19 | "architect audit"] both borders. The non-empty branch fallback (line 62) lacks column-width enforcement
- [2026-03-19 | "architect audit"] but this requires `printf` to fail, which is essentially impossible (bash builtin).
- [2026-03-19 | "architect audit"] The severity is too low and the observation too inaccurate to warrant a code change
- [2026-03-19 | "architect audit"] this cycle. Defer.
- [2026-03-19 | "architect audit"] **Observation 8 — `lib/common.sh:77-86` vs `132-141` `_box_line`/`_rbox_line`:**
- [2026-03-19 | "architect audit"] No functions named `_box_line` or `_rbox_line` exist anywhere in `lib/common.sh`.
- [2026-03-19 | "architect audit"] Grep confirms zero matches. The observation is stale — these names predate the
- [2026-03-19 | "architect audit"] current implementation. Resolved.

## Resolved
- [RESOLVED 2026-03-19] `lib/notes.sh` (file-level): Missing `set -euo pipefail` at the top of the file. All other sourced libraries in `lib/` have it (e.g., `drift_cleanup.sh:11`, `config_defaults.sh:8`). This is a pre-existing issue but the file was modified in this milestone and is now the only library in `lib/` without it. CLAUDE.md rule: "All scripts use `set -euo pipefail`."
- [RESOLVED 2026-03-19] Both the Sr Coder and Jr Coder touched the `agent_monitor.sh` header (lines 3-4). Sr Coder updated it as part of the extraction; Jr Coder confirmed it was already correct. No double-write conflict occurred — final state is correct. This is expected coordination when Simplification and Staleness items touch the same file, not a process concern.
- [RESOLVED 2026-03-19] `stages/tester.sh:101` — the pipeline `grep ... | tee -a "$LOG_FILE"` appends grep output to the log. If `$LOG_FILE` is the same file already being written by `run_agent`, this can produce duplicate entries. Not introduced by this milestone but worth flagging for the audit log.
- [RESOLVED 2026-03-19] `lib/config.sh` is 342 lines — exceeds the 300-line ceiling. Pre-existing issue, no changes to scope in this rework. Candidate for a future `lib/config_defaults.sh` extraction.
- [RESOLVED 2026-03-19] `lib/agent_monitor.sh` remains well over 300 lines. Pre-existing, noted in prior review. Warrants a future split.
- [RESOLVED 2026-03-19] `lib/agent_monitor.sh:211` — The activity-timeout kill sequence inside the FIFO reader subshell uses `kill "$_TEKHTON_AGENT_PID"` directly, but the outer `_run_agent_abort` trap already does the same. These two kill paths are logically duplicated. Not a bug — the subshell can't reach the trap — but worth a comment explaining why the inner kill is necessary.
- [RESOLVED 2026-03-19] `lib/common.sh:61-65` — `_print_box_line` falls back to a bare `echo "${_bv}"` (no padding, no right border) when `printf` fails. On any system where printf is absent the empty-line rendering will be visually broken. The same fallback pattern exists in the content branch. Low likelihood in practice.
- [RESOLVED 2026-03-19] `lib/common.sh:77-86` vs `lib/common.sh:132-141`: `_box_line` and `_rbox_line` are nested functions with identical implementations (identical `printf` calls, identical fallback `echo`). The only difference is the name. If a future contributor modifies one without the other, the rendering diverges silently.
