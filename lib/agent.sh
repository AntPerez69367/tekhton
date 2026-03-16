#!/usr/bin/env bash
# =============================================================================
# agent.sh — Agent invocation wrapper with metrics tracking + exit detection
#
# Sourced by tekhton.sh — do not run directly.
# Expects: TOTAL_TURNS, TOTAL_TIME, STAGE_SUMMARY (set by caller)
# Expects: log(), success(), warn(), error() from common.sh
# =============================================================================

# Source monitoring infrastructure (FIFO loop, activity detection, process mgmt)
# shellcheck source=lib/agent_monitor.sh
source "${TEKHTON_HOME}/lib/agent_monitor.sh"

# --- Metrics accumulators (initialize if not already set) --------------------

: "${TOTAL_TURNS:=0}"
: "${TOTAL_TIME:=0}"
: "${STAGE_SUMMARY:=}"

# --- Agent Tool Profiles (least-privilege allowlists) ------------------------
# Each profile uses --allowedTools to restrict Claude CLI tool access per role.
# Override with AGENT_SKIP_PERMISSIONS=true for --dangerously-skip-permissions.

# SCOUT: read-only discovery. Finds relevant files, reads headers.
# NOTE: Write is included because the scout must create SCOUT_REPORT.md.
# The Claude CLI does not support path-scoped write restrictions, so the scout
# technically has write access to any file. This is a known least-privilege gap —
# the scout prompt restricts it to writing only SCOUT_REPORT.md.
export AGENT_TOOLS_SCOUT="Read Glob Grep Bash(find:*) Bash(head:*) Bash(wc:*) Bash(cat:*) Bash(ls:*) Bash(tail:*) Bash(file:*) Write"

# CODER: full implementation agent. Reads, writes, edits code, runs analyze/test.
# Bash access is broad but blocks destructive operations via disallowed tools.
export AGENT_TOOLS_CODER="Read Write Edit Glob Grep Bash"

# JR_CODER: same as coder but for simpler tasks. Same tool access.
export AGENT_TOOLS_JR_CODER="Read Write Edit Glob Grep Bash"

# REVIEWER: reads code and writes a report. No code edits, no bash.
export AGENT_TOOLS_REVIEWER="Read Glob Grep Write"

# TESTER: writes test files, runs test commands. Needs bash for $TEST_CMD.
export AGENT_TOOLS_TESTER="Read Write Edit Glob Grep Bash"

# ARCHITECT: reads drift logs and source, writes a plan. No code edits, no bash.
export AGENT_TOOLS_ARCHITECT="Read Glob Grep Write"

# BUILD_FIX: targeted code fixes + build verification. Needs bash for build check.
export AGENT_TOOLS_BUILD_FIX="Read Write Edit Glob Grep Bash"

# SEED_CONTRACTS: adds doc comments to source files, runs analyze.
export AGENT_TOOLS_SEED="Read Write Edit Glob Grep Bash"

# CLEANUP: analyze cleanup pass — fix lint warnings, runs analyze.
export AGENT_TOOLS_CLEANUP="Read Write Edit Glob Grep Bash"

# Disallowed tools for ALL agents — best-effort denylist for destructive ops.
# NOTE: agents can bypass via alternative command forms; --allowedTools is the
# primary security boundary. This is one layer in a defense-in-depth strategy.
AGENT_DISALLOWED_TOOLS="WebFetch WebSearch Bash(git push:*) Bash(git remote:*) Bash(rm -rf /:*) Bash(rm -rf ~:*) Bash(rm -rf .:*) Bash(rm -rf ..:*) Bash(curl:*) Bash(wget:*) Bash(ssh:*) Bash(scp:*) Bash(nc:*) Bash(ncat:*)"

# --- Agent exit detection globals --------------------------------------------
# Set after every run_agent() call. Callers inspect these to decide next steps.

LAST_AGENT_TURNS=0         # Turns the agent actually used
LAST_AGENT_EXIT_CODE=0     # claude CLI exit code
LAST_AGENT_ELAPSED=0       # Wall-clock seconds
LAST_AGENT_NULL_RUN=false  # true if agent likely died without doing work

# --- Run summary -------------------------------------------------------------

print_run_summary() {
    local total_mins=$(( TOTAL_TIME / 60 ))
    local total_secs=$(( TOTAL_TIME % 60 ))
    echo
    echo "══════════════════════════════════════"
    echo "  Run Summary"
    echo "══════════════════════════════════════"
    echo -e "$STAGE_SUMMARY"
    echo "  ──────────────────────────────────"
    echo "  Total turns: ${TOTAL_TURNS}"
    echo "  Total time:  ${total_mins}m${total_secs}s"
    if [ -n "${LAST_CONTEXT_TOKENS:-}" ] && [ "${LAST_CONTEXT_TOKENS:-0}" -gt 0 ]; then
        local ctx_k=$(( LAST_CONTEXT_TOKENS / 1000 ))
        echo "  Context:     ~${ctx_k}k tokens (${LAST_CONTEXT_PCT:-0}% of window)"
    fi
    echo "══════════════════════════════════════"
    echo
}

# --- Agent invocation wrapper — tracks turns and wall-clock time per stage ----
run_agent() {
    local label="$1"        # e.g. "Coder", "Reviewer", "Tester"
    local model="$2"
    local max_turns="$3"
    local prompt="$4"
    local log_file="$5"
    local allowed_tools="${6:-$AGENT_TOOLS_CODER}"  # default: coder-level access

    local start_time
    start_time=$(date +%s)

    # Disable pipefail — claude can exit non-zero on turn limits
    set +o pipefail

    local _timeout="${AGENT_TIMEOUT:-7200}"  # 0 to disable
    local _invoke
    if [ "$_timeout" -gt 0 ] 2>/dev/null && command -v timeout &>/dev/null; then
        _invoke="timeout ${_TIMEOUT_KILL_AFTER_FLAG} $_timeout"
    else
        _invoke=""
    fi

    local _activity_timeout="${AGENT_ACTIVITY_TIMEOUT:-600}"  # 0 to disable

    local _session_dir="${TEKHTON_SESSION_DIR:-/tmp}"
    local _turns_file="${_session_dir}/agent_last_turns"
    local _exit_file="${_session_dir}/agent_exit"
    rm -f "$_exit_file" "$_turns_file"

    # Pre-run marker for file-change detection
    local _prerun_marker="${_session_dir}/prerun_marker"
    touch "$_prerun_marker"

    # --- Build permission flags -----------------------------------------------
    # Default: use --allowedTools + --disallowedTools for least-privilege.
    # Override: set AGENT_SKIP_PERMISSIONS=true in pipeline.conf for the old
    # --dangerously-skip-permissions behavior (NOT recommended).
    local -a _perm_flags=()
    if [ "${AGENT_SKIP_PERMISSIONS:-false}" = true ]; then
        _perm_flags=(--dangerously-skip-permissions)
        if [ "${_AGENT_PERM_WARNED:-}" != true ]; then
            warn "[agent] AGENT_SKIP_PERMISSIONS=true — agents have unrestricted access."
            warn "[agent] This is NOT recommended. Set to false in pipeline.conf."
            _AGENT_PERM_WARNED=true
        fi
    else
        _perm_flags=(--allowedTools "$allowed_tools")
        # Apply disallowed tools for agents with Bash access
        if echo "$allowed_tools" | grep -q 'Bash'; then
            _perm_flags+=(--disallowedTools "$AGENT_DISALLOWED_TOOLS")
        fi
    fi

    # Pass perm flags to the monitor via global array
    _IM_PERM_FLAGS=("${_perm_flags[@]}")

    # Invoke agent with FIFO monitoring (or direct pipeline fallback)
    _invoke_and_monitor "$_invoke" "$model" "$max_turns" "$prompt" \
        "$log_file" "$_activity_timeout" "$_session_dir" "$_exit_file" "$_turns_file"

    local agent_exit="$_MONITOR_EXIT_CODE"
    local _was_activity_timeout="$_MONITOR_WAS_ACTIVITY_TIMEOUT"

    trap - INT TERM
    set -o pipefail

    if [ "$agent_exit" -ne 0 ]; then
        if [ "$agent_exit" -eq 124 ]; then
            if [ "$_was_activity_timeout" = true ]; then
                warn "[$label] ACTIVITY TIMEOUT — agent produced no output for ${_activity_timeout}s."
                warn "[$label] This usually means claude hung on an API call or entered a retry loop."
                warn "[$label] Set AGENT_ACTIVITY_TIMEOUT in pipeline.conf to change (0 = disable)."
            else
                warn "[$label] TIMEOUT — agent did not complete within ${_timeout}s. Set AGENT_TIMEOUT in pipeline.conf to change."
            fi
        else
            warn "[$label] claude exited with code ${agent_exit} (may indicate turn limit or error)"
        fi
    fi

    local end_time
    end_time=$(date +%s)
    local elapsed=$(( end_time - start_time ))
    local mins=$(( elapsed / 60 ))
    local secs=$(( elapsed % 60 ))
    local turns_used
    turns_used=$(cat "$_turns_file" 2>/dev/null || echo "0")
    [[ "$turns_used" =~ ^[0-9]+$ ]] || turns_used=0

    # Detect overshoot — Claude CLI's --max-turns is a soft cap
    local turns_display="${turns_used}/${max_turns}"
    if [ "$turns_used" -gt "$max_turns" ] 2>/dev/null; then
        turns_display="${turns_used}/${max_turns} (overshot by $(( turns_used - max_turns )))"
    fi

    log "[$label] Turns: ${turns_display} | Time: ${mins}m${secs}s"

    # Accumulate run totals
    TOTAL_TURNS=$(( TOTAL_TURNS + turns_used ))
    TOTAL_TIME=$(( TOTAL_TIME + elapsed ))

    # Store per-stage for summary
    STAGE_SUMMARY="${STAGE_SUMMARY}\n  ${label}: ${turns_display} turns, ${mins}m${secs}s"

    # --- Agent exit detection ------------------------------------------------
    # Populate LAST_AGENT_* globals so callers can check for null runs.
    #
    # Milestone 0.5: Before declaring a null run, check for file-system changes
    # and CODER_SUMMARY.md existence. JSON output mode agents may complete work
    # silently (no FIFO output, no extractable turn count) but still modify
    # files successfully. File changes override the null-run heuristic.

    export LAST_AGENT_TURNS="$turns_used"
    export LAST_AGENT_EXIT_CODE="$agent_exit"
    export LAST_AGENT_ELAPSED="$elapsed"
    LAST_AGENT_NULL_RUN=false

    # Check for file-system changes SINCE THE AGENT STARTED as a secondary
    # productivity signal. Uses the pre-run marker so we only detect changes
    # made during this agent run, not pre-existing uncommitted changes.
    local _has_file_changes=false
    if [ -f "$_prerun_marker" ] && _detect_file_changes "$_prerun_marker"; then
        _has_file_changes=true
    fi

    # Check for CODER_SUMMARY.md as a completion signal — if the agent wrote
    # its summary file during this run, it completed meaningful work regardless
    # of turn count. Only counts if the file is newer than the pre-run marker.
    local _has_summary=false
    local _summary_path="${PROJECT_DIR:-.}/CODER_SUMMARY.md"
    if [ -f "$_summary_path" ] && [ -f "$_prerun_marker" ]; then
        if [ "$_summary_path" -nt "$_prerun_marker" ]; then
            local _summary_lines
            _summary_lines=$(wc -l < "$_summary_path" 2>/dev/null | tr -d '[:space:]')
            if [ "${_summary_lines:-0}" -ge 3 ]; then
                _has_summary=true
            fi
        fi
    fi

    # Null run heuristic: agent used very few turns (≤2) OR exited non-zero
    # with zero turns. This typically means it died during discovery/search.
    # Exit 124 = timeout — always a null run regardless of turn count,
    # UNLESS files were modified (indicating the agent did productive work).
    local null_threshold="${AGENT_NULL_RUN_THRESHOLD:-2}"
    local _changed_count="0"
    if [ "$_has_file_changes" = true ]; then
        _changed_count=$(_count_changed_files_since "$_prerun_marker")
    fi
    if [ "$agent_exit" -eq 124 ]; then
        if [ "$_has_file_changes" = true ] || [ "$_has_summary" = true ]; then
            # Agent timed out but produced file changes — NOT a null run.
            if [ "$_was_activity_timeout" = true ]; then
                warn "[$label] Activity timeout fired but agent modified ${_changed_count} file(s) — classifying as productive run."
            else
                warn "[$label] Timeout fired but agent modified ${_changed_count} file(s) — classifying as productive run."
            fi
        else
            LAST_AGENT_NULL_RUN=true
            if [ "$_was_activity_timeout" = true ]; then
                warn "[$label] NULL RUN DETECTED — agent activity-timed out after ${_activity_timeout}s of silence."
            else
                if [ "$_timeout" -gt 0 ] 2>/dev/null; then
                    warn "[$label] NULL RUN DETECTED — agent timed out after ${_timeout}s."
                else
                    warn "[$label] NULL RUN DETECTED — agent timed out (outer timeout disabled)."
                fi
            fi
        fi
    elif [ "$turns_used" -le "$null_threshold" ] && [ "$agent_exit" -ne 0 ]; then
        if [ "$_has_file_changes" = true ] || [ "$_has_summary" = true ]; then
            warn "[$label] Low turn count (${turns_used}) with exit ${agent_exit}, but agent modified ${_changed_count} file(s) — NOT a null run."
        else
            LAST_AGENT_NULL_RUN=true
            warn "[$label] NULL RUN DETECTED — agent used ${turns_used} turn(s) and exited ${agent_exit}."
            # Provide specific guidance based on exit code
            if [ "$agent_exit" -eq 137 ]; then
                warn "[$label] Exit 137 = SIGKILL (signal 9). The process was killed externally."
                warn "[$label] Common cause: OOM killer in WSL2, or the prompt was too large for available memory."
            elif [ "$agent_exit" -eq 139 ]; then
                warn "[$label] Exit 139 = SIGSEGV. The process crashed."
            else
                warn "[$label] The agent likely died during initial discovery/file search."
            fi
        fi
    elif [ "$turns_used" -eq 0 ]; then
        if [ "$_has_file_changes" = true ] || [ "$_has_summary" = true ]; then
            warn "[$label] 0 turns reported but agent modified ${_changed_count} file(s) — NOT a null run."
        else
            LAST_AGENT_NULL_RUN=true
            warn "[$label] NULL RUN DETECTED — agent used 0 turns."
        fi
    fi
}

# =============================================================================
# NULL RUN DETECTION HELPERS
# Call these after run_agent() to check if the agent accomplished anything.
# =============================================================================

# was_null_run — returns 0 (true) if the last agent invocation was a null run.
# A null run is one where the agent died before accomplishing meaningful work.
was_null_run() {
    [ "$LAST_AGENT_NULL_RUN" = true ]
}

# check_agent_output — verifies an agent produced its expected output file and
# made git changes. Returns 0 if the agent produced meaningful work.
#
# Usage:  check_agent_output "CODER_SUMMARY.md" "Coder"
# Returns: 0 if output file exists AND (git has changes OR output file has content)
#          1 if null run or no meaningful output
check_agent_output() {
    local expected_file="$1"
    local label="$2"

    # If the agent was already flagged as a null run, fail immediately
    if was_null_run; then
        warn "[$label] Agent was a null run — no output expected."
        return 1
    fi

    # Check for expected output file
    if [ ! -f "$expected_file" ]; then
        warn "[$label] Expected output file '${expected_file}' not found."
        return 1
    fi

    # Check if the file has meaningful content (more than just a header)
    local line_count
    line_count=$(wc -l < "$expected_file" | tr -d '[:space:]')
    if [ "$line_count" -lt 3 ]; then
        warn "[$label] Output file '${expected_file}' has only ${line_count} line(s) — likely a stub."
        return 1
    fi

    # Check for git changes (the agent might have produced a report but changed no code)
    local has_changes=false
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        has_changes=true
    fi

    if [ "$has_changes" = false ] && [ "$line_count" -lt 5 ]; then
        warn "[$label] No git changes and minimal output — agent may not have accomplished anything."
        return 1
    fi

    return 0
}
