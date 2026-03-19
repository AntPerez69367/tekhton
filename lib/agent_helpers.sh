#!/usr/bin/env bash
# =============================================================================
# agent_helpers.sh — Agent run summary, output validation, null-run helpers,
#                    and transient retry envelope
#
# Sourced by agent.sh — do not run directly.
# Expects: TOTAL_TURNS, TOTAL_TIME, STAGE_SUMMARY (set by caller)
# Expects: log(), success(), warn(), error() from common.sh
# Expects: AGENT_ERROR_* globals from agent.sh
# =============================================================================

# --- Transient retry envelope (13.2.1) ---------------------------------------
# Wraps _invoke_and_monitor in a retry loop with error classification and
# exponential backoff. Sets globals for run_agent() to consume:
#   AGENT_ERROR_CATEGORY, AGENT_ERROR_SUBCATEGORY, AGENT_ERROR_TRANSIENT,
#   AGENT_ERROR_MESSAGE, LAST_AGENT_RETRY_COUNT,
#   _RWR_EXIT, _RWR_TURNS, _RWR_WAS_ACTIVITY_TIMEOUT
_run_with_retry() {
    local label="$1"
    local invoke_cmd="$2"
    local model="$3"
    local max_turns="$4"
    local prompt="$5"
    local log_file="$6"
    local activity_timeout="$7"
    local session_dir="$8"
    local exit_file="$9"
    local turns_file="${10}"
    local prerun_marker="${11}"
    local wall_timeout="${12}"

    LAST_AGENT_RETRY_COUNT=0
    local _retry_attempt=0
    _RWR_EXIT=0
    _RWR_WAS_ACTIVITY_TIMEOUT=false
    _RWR_TURNS=0

    while true; do
        # Reset error classification for this attempt
        AGENT_ERROR_CATEGORY=""
        AGENT_ERROR_SUBCATEGORY=""
        AGENT_ERROR_TRANSIENT=""
        AGENT_ERROR_MESSAGE=""

        _invoke_and_monitor "$invoke_cmd" "$model" "$max_turns" "$prompt" \
            "$log_file" "$activity_timeout" "$session_dir" "$exit_file" "$turns_file"

        _RWR_EXIT="$_MONITOR_EXIT_CODE"
        _RWR_WAS_ACTIVITY_TIMEOUT="$_MONITOR_WAS_ACTIVITY_TIMEOUT"

        trap - INT TERM

        # Extract turn count (needed for error classification below)
        _RWR_TURNS=$(cat "$turns_file" 2>/dev/null || echo "0")
        [[ "$_RWR_TURNS" =~ ^[0-9]+$ ]] || _RWR_TURNS=0

        if [ "$_RWR_EXIT" -ne 0 ]; then
            if [ "$_RWR_EXIT" -eq 124 ]; then
                if [ "$_RWR_WAS_ACTIVITY_TIMEOUT" = true ]; then
                    warn "[$label] ACTIVITY TIMEOUT — agent produced no output for ${activity_timeout}s."
                    warn "[$label] This usually means claude hung on an API call or entered a retry loop."
                    warn "[$label] Set AGENT_ACTIVITY_TIMEOUT in pipeline.conf to change (0 = disable)."
                else
                    warn "[$label] TIMEOUT — agent did not complete within ${wall_timeout}s. Set AGENT_TIMEOUT in pipeline.conf to change."
                fi
            else
                warn "[$label] claude exited with code ${_RWR_EXIT} (may indicate turn limit or error)"
            fi
        fi

        # --- Error classification (12.2) --------------------------------------
        _classify_agent_exit "$_RWR_EXIT" "$session_dir" "$prerun_marker" "$_RWR_TURNS"

        # --- Transient retry check (13.2.1) -----------------------------------
        if _should_retry_transient "$label" "$_retry_attempt" "$session_dir" \
            "$exit_file" "$turns_file"; then
            _retry_attempt=$(( _retry_attempt + 1 ))
            # shellcheck disable=SC2034  # used by run_agent() to track retry count
            LAST_AGENT_RETRY_COUNT=$_retry_attempt
            continue
        fi

        break
    done
}

# _classify_agent_exit EXIT SESSION_DIR PRERUN_MARKER TURNS
# Runs classify_error and sets AGENT_ERROR_* globals.
_classify_agent_exit() {
    local agent_exit="$1"
    local session_dir="$2"
    local prerun_marker="$3"
    local turns_used="$4"

    if [[ "$agent_exit" -ne 0 ]] || [[ "$_API_ERROR_DETECTED" = true ]]; then
        # classify_error is from lib/errors.sh — guard for tests that source agent.sh directly
        if command -v classify_error &>/dev/null; then
            local _stderr_file="${session_dir}/agent_stderr.txt"
            local _last_output_file="${session_dir}/agent_last_output.txt"
            local _fc=0
            if [[ -f "$prerun_marker" ]] && _detect_file_changes "$prerun_marker"; then
                _fc=$(_count_changed_files_since "$prerun_marker")
            fi

            # If API error was detected in stream but stderr file is still empty
            if [[ "$_API_ERROR_DETECTED" = true ]] && [[ ! -s "$_stderr_file" ]]; then
                echo "API error detected in stream: ${_API_ERROR_TYPE}" > "$_stderr_file"
            fi

            # Check for CODER_SUMMARY.md presence
            local _has_summary_flag=0
            local _summary_check_path="${PROJECT_DIR:-.}/CODER_SUMMARY.md"
            if [[ -f "$_summary_check_path" ]] && [[ -f "$prerun_marker" ]] \
                && [[ "$_summary_check_path" -nt "$prerun_marker" ]]; then
                _has_summary_flag=1
            fi

            local _error_record
            _error_record=$(classify_error "$agent_exit" "$_stderr_file" "$_last_output_file" "$_fc" "$turns_used" "$_has_summary_flag")

            AGENT_ERROR_CATEGORY=$(echo "$_error_record" | cut -d'|' -f1)
            AGENT_ERROR_SUBCATEGORY=$(echo "$_error_record" | cut -d'|' -f2)
            AGENT_ERROR_TRANSIENT=$(echo "$_error_record" | cut -d'|' -f3)
            AGENT_ERROR_MESSAGE=$(echo "$_error_record" | cut -d'|' -f4-)
        fi
    fi
}

# _should_retry_transient LABEL ATTEMPT SESSION_DIR EXIT_FILE TURNS_FILE
# Returns 0 (true) if a retry should occur (after sleeping), 1 otherwise.
_should_retry_transient() {
    local label="$1"
    local retry_attempt="$2"
    local session_dir="$3"
    local exit_file="$4"
    local turns_file="$5"

    if [[ "${TRANSIENT_RETRY_ENABLED:-true}" != true ]]; then
        return 1
    fi
    if [[ "$AGENT_ERROR_TRANSIENT" != "true" ]]; then
        return 1
    fi
    if [[ "$retry_attempt" -ge "${MAX_TRANSIENT_RETRIES:-3}" ]]; then
        return 1
    fi

    local _next_attempt=$(( retry_attempt + 1 ))

    # Exponential backoff: base * 2^(attempt-1), capped at max
    local _delay="${TRANSIENT_RETRY_BASE_DELAY:-30}"
    local _exp=$(( _next_attempt - 1 ))
    local _i=0
    while [[ "$_i" -lt "$_exp" ]]; do
        _delay=$(( _delay * 2 ))
        _i=$(( _i + 1 ))
    done
    if [[ "$_delay" -gt "${TRANSIENT_RETRY_MAX_DELAY:-120}" ]]; then
        _delay="${TRANSIENT_RETRY_MAX_DELAY:-120}"
    fi

    # Subcategory-specific minimum delays
    case "${AGENT_ERROR_SUBCATEGORY}" in
        api_rate_limit)
            local _retry_after=""
            if [[ -f "${session_dir}/agent_last_output.txt" ]]; then
                _retry_after=$(grep -oiE '"retry.after"[[:space:]]*:[[:space:]]*"?[0-9]+"?' \
                    "${session_dir}/agent_last_output.txt" 2>/dev/null \
                    | grep -oE '[0-9]+' | head -1)
            fi
            if [[ -n "${_retry_after:-}" ]] && [[ "$_retry_after" -gt "$_delay" ]] 2>/dev/null; then
                _delay="$_retry_after"
            elif [[ "$_delay" -lt 60 ]]; then
                _delay=60
            fi
            ;;
        api_overloaded)
            [[ "$_delay" -lt 60 ]] && _delay=60
            ;;
        oom)
            _delay=15
            ;;
    esac

    report_retry "$_next_attempt" "${MAX_TRANSIENT_RETRIES:-3}" \
        "${AGENT_ERROR_SUBCATEGORY}" "$_delay"
    log "[$label] Sleeping ${_delay}s before retry attempt ${_next_attempt}/${MAX_TRANSIENT_RETRIES:-3}..."
    sleep "$_delay"

    # Clean up monitoring state for the next attempt
    _reset_monitoring_state "$session_dir"
    rm -f "$exit_file" "$turns_file"

    return 0
}

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
    # LAST_CONTEXT_TOKENS reflects the most recently completed stage only (by design).
    # Each stage calls log_context_report() which resets and re-exports LAST_CONTEXT_TOKENS.
    # The final summary therefore shows the tester's context, not the coder's (typically
    # largest). Per-stage context breakdowns are logged individually during each stage.
    # This is intentional: the run summary is a snapshot, not an aggregate. Detailed
    # per-stage context data is available in the run log output.
    if [[ -n "${LAST_CONTEXT_TOKENS:-}" ]] && [[ "${LAST_CONTEXT_TOKENS:-0}" -gt 0 ]]; then
        local ctx_k=$(( LAST_CONTEXT_TOKENS / 1000 ))
        echo "  Context:     ~${ctx_k}k tokens (${LAST_CONTEXT_PCT:-0}% of window)"
    fi
    echo "══════════════════════════════════════"
    echo
}

# --- Structured agent run summary (12.3) — appended to log file end ----------
_append_agent_summary() {
    local label="$1" model="$2" turns_used="$3" max_turns="$4"
    local mins="$5" secs="$6" exit_code="$7" files_changed="$8"
    local log_file="$9"

    # Detect Unicode for consistent rendering with report_error
    local _sep="═══"
    if ! _is_utf8_terminal; then
        _sep="==="
    fi

    local _class="SUCCESS"
    if [[ "$exit_code" -ne 0 ]]; then
        if [[ -n "$AGENT_ERROR_CATEGORY" ]]; then
            _class="${AGENT_ERROR_CATEGORY}/${AGENT_ERROR_SUBCATEGORY}"
        elif [[ "$LAST_AGENT_NULL_RUN" = true ]]; then
            _class="NULL_RUN"
        else
            _class="FAILED (exit ${exit_code})"
        fi
    fi

    # Count created files (heuristic: new untracked files since prerun marker)
    local _created=0
    local _modified="${files_changed}"
    if command -v git &>/dev/null; then
        _created=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d '[:space:]')
        _created="${_created:-0}"
    fi

    local _summary_block
    _summary_block=$(cat <<AGENTSUMMARY

${_sep} Agent Run Summary ${_sep}
Agent:     ${label} (${model})
Turns:     ${turns_used} / ${max_turns}
Duration:  ${mins}m ${secs}s
Exit Code: ${exit_code}
Class:     ${_class}
Files:     ${_modified} modified, ${_created} created
AGENTSUMMARY
)

    # Add error details on failure
    if [[ "$_class" != "SUCCESS" ]] && [[ -n "$AGENT_ERROR_CATEGORY" ]]; then
        local _recovery=""
        if command -v suggest_recovery &>/dev/null; then
            _recovery=$(suggest_recovery "$AGENT_ERROR_CATEGORY" "$AGENT_ERROR_SUBCATEGORY")
        fi
        _summary_block="${_summary_block}
Error:     ${AGENT_ERROR_MESSAGE}
Recovery:  ${_recovery}"
    fi

    _summary_block="${_summary_block}
${_sep}${_sep}${_sep}${_sep}${_sep}${_sep}"

    # Redact sensitive data before writing to log
    if command -v redact_sensitive &>/dev/null; then
        _summary_block=$(redact_sensitive "$_summary_block")
    fi

    echo "$_summary_block" >> "$log_file"
}

# --- Null run detection helpers (call after run_agent()) --------------------

# was_null_run — true if last agent died before accomplishing meaningful work.
was_null_run() {
    [ "$LAST_AGENT_NULL_RUN" = true ]
}

# check_agent_output FILE LABEL — returns 0 if agent produced meaningful work.
check_agent_output() {
    local expected_file="$1"
    local label="$2"

    if was_null_run; then
        warn "[$label] Agent was a null run — no output expected."
        return 1
    fi

    if [ ! -f "$expected_file" ]; then
        warn "[$label] Expected output file '${expected_file}' not found."
        return 1
    fi

    local line_count
    line_count=$(count_lines < "$expected_file")
    if [ "$line_count" -lt 3 ]; then
        warn "[$label] Output file '${expected_file}' has only ${line_count} line(s) — likely a stub."
        return 1
    fi

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
