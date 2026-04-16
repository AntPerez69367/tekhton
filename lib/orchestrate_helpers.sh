#!/usr/bin/env bash
set -euo pipefail
# =============================================================================
# orchestrate_helpers.sh — Helper functions for the orchestration loop
#
# Extracted from orchestrate.sh to stay under the 300-line ceiling.
# Sourced by orchestrate.sh — do not run directly.
# =============================================================================

# --- Auto-advance chain (reused from existing logic) --------------------------

_run_auto_advance_chain() {
    while should_auto_advance 2>/dev/null; do
        local next_ms
        next_ms=$(find_next_milestone "$_CURRENT_MILESTONE" "CLAUDE.md")
        if [[ -z "$next_ms" ]]; then
            log "No more milestones to advance to."
            break
        fi

        local next_title
        next_title=$(get_milestone_title "$next_ms")

        if [[ "${AUTO_ADVANCE_CONFIRM:-true}" = "true" ]]; then
            if ! prompt_auto_advance_confirm "$next_ms" "$next_title"; then
                log "Auto-advance declined by user."
                break
            fi
        fi

        # Bump the in-memory session counter BEFORE the advance so the banner
        # and limit check see the correct count.
        _AA_SESSION_ADVANCES=$(( ${_AA_SESSION_ADVANCES:-0} + 1 ))
        export _AA_SESSION_ADVANCES

        # finalize_run already deleted MILESTONE_STATE_FILE; recreate it for the
        # new milestone before advance_milestone reads/writes it.
        local _total
        _total=$(get_milestone_count "CLAUDE.md")
        init_milestone_state "$next_ms" "$_total"

        advance_milestone "$_CURRENT_MILESTONE" "$next_ms"
        _CURRENT_MILESTONE="$next_ms"
        TASK="Implement Milestone ${_CURRENT_MILESTONE}: ${next_title}"
        START_AT="coder"

        # M16: Reset per-milestone tracking — successful milestone is forward progress
        _ORCH_REVIEW_BUMPED=false
        _ORCH_ATTEMPT=0
        _ORCH_NO_PROGRESS_COUNT=0
        _ORCH_LAST_ACCEPTANCE_HASH=""
        _ORCH_IDENTICAL_ACCEPTANCE_COUNT=0

        emit_milestone_metadata "$_CURRENT_MILESTONE" "in_progress" || true
        # Refresh dashboard milestones so the "in_progress" status is visible.
        # Guard: always true under tekhton.sh (dashboard_emitters.sh is sourced),
        # but kept for safety if this function is ever sourced standalone.
        if command -v emit_dashboard_milestones &>/dev/null; then
            emit_dashboard_milestones 2>/dev/null || true
        fi

        # Re-enter the complete loop for the new milestone.
        # Recursion depth is bounded by AUTO_ADVANCE_LIMIT (default 3) — the
        # should_auto_advance() guard at the top of this while loop exits once
        # the in-memory _AA_SESSION_ADVANCES counter reaches the limit.
        run_complete_loop
        return $?
    done
}

# --- Preflight fix helper (M44) -----------------------------------------------

# _try_preflight_fix PREFLIGHT_OUTPUT PREFLIGHT_EXIT
# Attempts a cheap Jr Coder fix before falling back to a full pipeline retry.
# The shell runs TEST_CMD independently after each fix attempt — the agent
# never sees its own test output.
# Returns 0 if tests pass after fix, 1 if fix attempts exhausted.
_try_preflight_fix() {
    local _pf_output="$1"
    local _pf_exit="$2"

    if [[ "${PREFLIGHT_FIX_ENABLED:-true}" != "true" ]]; then
        return 1
    fi

    local _pf_max="${PREFLIGHT_FIX_MAX_ATTEMPTS:-2}"
    local _pf_model="${PREFLIGHT_FIX_MODEL:-${CLAUDE_JR_CODER_MODEL:-claude-sonnet-4-6}}"
    local _pf_turns="${EFFECTIVE_JR_CODER_MAX_TURNS:-${PREFLIGHT_FIX_MAX_TURNS:-${JR_CODER_MAX_TURNS:-40}}}"
    local _pf_attempt=0

    # Gather changed files for context
    local _pf_changed_files=""
    if [[ -f "${CODER_SUMMARY_FILE}" ]]; then
        _pf_changed_files=$(sed -n '/^## Files/,/^## /p' "${CODER_SUMMARY_FILE}" | grep -E '^\s*[-*]' | head -30 || true)
    fi
    if [[ -z "$_pf_changed_files" ]]; then
        _pf_changed_files=$(git diff --name-only HEAD 2>/dev/null | head -30 || true)
    fi

    # Capture initial failure signature for regression detection
    # Note: grep pattern counts keyword occurrences and may over-count in test frameworks
    # that print "0 errors" or "no failures found" in passing output. This is accepted
    # because the heuristic uses exit codes for correctness; grep counts only throttle
    # early-abort decisions (see regression check below).
    local _pf_initial_fail_count
    _pf_initial_fail_count=$(printf '%s\n' "$_pf_output" | grep -ciE '(FAIL|ERROR|error|failure)' || echo "0")

    while [[ "$_pf_attempt" -lt "$_pf_max" ]]; do
        _pf_attempt=$(( _pf_attempt + 1 ))
        warn "Pre-finalization fix: Jr Coder attempt ${_pf_attempt}/${_pf_max}..."

        # Emit causal log event if available
        if declare -f emit_event &>/dev/null; then
            emit_event "preflight_fix_start" "preflight_fix" \
                "attempt ${_pf_attempt}/${_pf_max}" "" "" "" > /dev/null 2>&1 || true
        fi

        # Set template variables for prompt rendering
        export PREFLIGHT_TEST_OUTPUT
        PREFLIGHT_TEST_OUTPUT=$(printf '%s\n' "$_pf_output" | tail -120)
        export PREFLIGHT_CHANGED_FILES="$_pf_changed_files"

        local _pf_prompt
        _pf_prompt=$(render_prompt "preflight_fix")

        # Invoke Jr Coder with restricted tools (no Bash test execution)
        run_agent \
            "Preflight Fix (attempt ${_pf_attempt})" \
            "$_pf_model" \
            "$_pf_turns" \
            "$_pf_prompt" \
            "$LOG_FILE" \
            "$AGENT_TOOLS_BUILD_FIX"

        # Shell independently runs TEST_CMD — agent never sees this output
        log "Pre-finalization fix: shell verifying with ${TEST_CMD}..."
        local _pf_verify_exit=0
        local _pf_verify_output=""
        _pf_verify_output=$(bash -c "${TEST_CMD}" 2>&1) || _pf_verify_exit=$?
        printf '%s\n' "$_pf_verify_output" >> "$LOG_FILE"

        if [[ "$_pf_verify_exit" -eq 0 ]]; then
            success "Pre-finalization fix: tests pass after attempt ${_pf_attempt}."
            if declare -f emit_event &>/dev/null; then
                emit_event "preflight_fix_end" "preflight_fix" \
                    "fixed on attempt ${_pf_attempt}" "" "" "" > /dev/null 2>&1 || true
            fi
            return 0
        fi

        # Regression detection: if fix introduced MORE failures, abort immediately
        local _pf_new_fail_count
        _pf_new_fail_count=$(printf '%s\n' "$_pf_verify_output" | grep -ciE '(FAIL|ERROR|error|failure)' || echo "0")
        # The +2 threshold accommodates slight variance in noisy grep counts. Frameworks
        # that print "0 errors" or "no failures found" can shift the count by 1–2 between
        # runs. This prevents aborting on measurement noise while still catching genuine
        # regressions (sustained growth in actual failures).
        if [[ "$_pf_new_fail_count" -gt "$(( _pf_initial_fail_count + 2 ))" ]]; then
            warn "Pre-finalization fix: attempt ${_pf_attempt} introduced new failures (${_pf_new_fail_count} vs ${_pf_initial_fail_count}). Aborting fix loop."
            break
        fi

        # Update output for next iteration
        _pf_output="$_pf_verify_output"
        warn "Pre-finalization fix: attempt ${_pf_attempt} did not resolve failures."
    done

    if declare -f emit_event &>/dev/null; then
        emit_event "preflight_fix_end" "preflight_fix" \
            "exhausted ${_pf_max} attempts" "" "" "" > /dev/null 2>&1 || true
    fi
    warn "Pre-finalization fix: exhausted ${_pf_max} attempts. Falling through to full retry."
    return 1
}

# --- Adaptive turn escalation (Milestone 91) ----------------------------------
#
# When the orchestrator hits AGENT_SCOPE/max_turns consecutively on the same
# stage within a --complete run, escalate the effective turn budget for the
# next attempt. Counter is tracked by run_complete_loop in
# _ORCH_CONSECUTIVE_MAX_TURNS / _ORCH_MAX_TURNS_STAGE.

# _update_escalation_counter FAILED_STAGE ERROR_CATEGORY ERROR_SUBCATEGORY
# Updates _ORCH_CONSECUTIVE_MAX_TURNS and _ORCH_MAX_TURNS_STAGE based on the
# last iteration's outcome. Call once per iteration regardless of outcome.
# Returns 0 if counter was incremented (escalation should apply), 1 otherwise.
_update_escalation_counter() {
    local _stage="${1:-}"
    local _cat="${2:-}"
    local _sub="${3:-}"

    if [[ "${REWORK_TURN_ESCALATION_ENABLED:-true}" != "true" ]]; then
        _ORCH_CONSECUTIVE_MAX_TURNS=0
        _ORCH_MAX_TURNS_STAGE=""
        unset EFFECTIVE_CODER_MAX_TURNS EFFECTIVE_JR_CODER_MAX_TURNS
        unset EFFECTIVE_TESTER_MAX_TURNS
        return 1
    fi

    if [[ "$_cat" = "AGENT_SCOPE" ]] && [[ "$_sub" = "max_turns" ]]; then
        if [[ -n "$_stage" ]] && [[ "$_stage" = "$_ORCH_MAX_TURNS_STAGE" ]]; then
            _ORCH_CONSECUTIVE_MAX_TURNS=$(( _ORCH_CONSECUTIVE_MAX_TURNS + 1 ))
        else
            _ORCH_CONSECUTIVE_MAX_TURNS=1
            _ORCH_MAX_TURNS_STAGE="$_stage"
        fi
        return 0
    fi

    # Any other outcome (success or non-max_turns failure) resets the counter
    _ORCH_CONSECUTIVE_MAX_TURNS=0
    _ORCH_MAX_TURNS_STAGE=""
    unset EFFECTIVE_CODER_MAX_TURNS EFFECTIVE_JR_CODER_MAX_TURNS
    unset EFFECTIVE_TESTER_MAX_TURNS
    return 1
}

# _escalate_turn_budget BASE_TURNS FACTOR COUNT CAP
# Echoes the escalated integer budget clamped to CAP. Uses awk when available,
# falls back to integer shell arithmetic (multiplying factor by 100).
_escalate_turn_budget() {
    local _base="$1"
    local _factor="$2"
    local _count="$3"
    local _cap="$4"
    local _multiplied

    if command -v awk &>/dev/null; then
        _multiplied=$(awk "BEGIN { printf \"%d\", int(${_base} * (1 + (${_factor} * ${_count}))) }")
    else
        # Fallback: multiply factor by 100 to avoid fractional math
        local _factor_x100
        _factor_x100=$(printf '%s' "$_factor" | awk -F. '{ if (NF==2) { sub(/0+$/,"",$2); printf "%d", $1*100 + ($2 "0" )/10**(length($2)-2) } else printf "%d", $1*100 }' 2>/dev/null || echo "150")
        [[ "$_factor_x100" =~ ^[0-9]+$ ]] || _factor_x100=150
        _multiplied=$(( _base + (_base * _factor_x100 * _count) / 100 ))
    fi

    [[ "$_multiplied" =~ ^[0-9]+$ ]] || _multiplied="$_base"
    if [[ "$_multiplied" -gt "$_cap" ]]; then
        _multiplied="$_cap"
    fi
    printf '%s\n' "$_multiplied"
}

# _apply_turn_escalation COUNT
# Computes and exports EFFECTIVE_CODER_MAX_TURNS, EFFECTIVE_JR_CODER_MAX_TURNS,
# and EFFECTIVE_TESTER_MAX_TURNS based on the current consecutive-max-turns
# count. Emits a warn line describing the new budget.
_apply_turn_escalation() {
    local _count="${1:-1}"
    local _factor="${REWORK_TURN_ESCALATION_FACTOR:-1.5}"
    local _cap="${REWORK_TURN_MAX_CAP:-${CODER_MAX_TURNS_CAP:-200}}"

    EFFECTIVE_CODER_MAX_TURNS=$(_escalate_turn_budget "${CODER_MAX_TURNS:-80}" "$_factor" "$_count" "$_cap")
    EFFECTIVE_JR_CODER_MAX_TURNS=$(_escalate_turn_budget "${JR_CODER_MAX_TURNS:-40}" "$_factor" "$_count" "$_cap")
    EFFECTIVE_TESTER_MAX_TURNS=$(_escalate_turn_budget "${TESTER_MAX_TURNS:-50}" "$_factor" "$_count" "$_cap")
    export EFFECTIVE_CODER_MAX_TURNS EFFECTIVE_JR_CODER_MAX_TURNS EFFECTIVE_TESTER_MAX_TURNS

    local _stage="${_ORCH_MAX_TURNS_STAGE:-unknown}"
    if [[ "$EFFECTIVE_CODER_MAX_TURNS" -ge "$_cap" ]]; then
        warn "[orchestrate] max_turns hit ${_count}x for ${_stage} — escalated to cap (${_cap}). Further failures will not escalate; consider --split-milestone."
    else
        warn "[orchestrate] max_turns hit ${_count}x for ${_stage} — escalating coder to ${EFFECTIVE_CODER_MAX_TURNS} turns (jr=${EFFECTIVE_JR_CODER_MAX_TURNS}, tester=${EFFECTIVE_TESTER_MAX_TURNS})."
    fi
}

# _can_escalate_further
# Returns 0 when escalation is enabled AND the current budget has not hit the cap.
# Used by the recovery branch to decide whether to retry with escalated budget
# instead of falling through to save_exit.
_can_escalate_further() {
    [[ "${REWORK_TURN_ESCALATION_ENABLED:-true}" = "true" ]] || return 1
    local _cap="${REWORK_TURN_MAX_CAP:-${CODER_MAX_TURNS_CAP:-200}}"
    [[ "${EFFECTIVE_CODER_MAX_TURNS:-0}" -lt "$_cap" ]]
}

# --- State persistence helper -------------------------------------------------

_save_orchestration_state() {
    local outcome="$1"
    local detail="$2"

    _ORCH_ELAPSED=$(( $(date +%s) - _ORCH_START_TIME ))

    # Run finalize hooks for failure path (metrics, archiving, but no commit)
    finalize_run 1

    # Build resume command with appropriate flags
    local resume_flags="--complete"
    if [[ "$MILESTONE_MODE" = true ]]; then
        resume_flags="--complete --milestone"
    fi
    resume_flags="${resume_flags} --start-at ${START_AT}"

    # Safety-bound exits (max_attempts, timeout, agent_cap) should write zeroed
    # counters so the next invocation starts with a fresh budget. The counter in
    # the state file is what gets restored on resume — if we write the exhausted
    # value, the next run would immediately re-hit the same bound.
    local _saved_attempt="$_ORCH_ATTEMPT"
    local _saved_calls="$_ORCH_AGENT_CALLS"
    case "$outcome" in
        max_attempts|timeout|agent_cap)
            _ORCH_ATTEMPT=0
            _ORCH_AGENT_CALLS=0
            ;;
    esac

    write_pipeline_state \
        "${START_AT}" \
        "complete_loop_${outcome}" \
        "$resume_flags" \
        "$TASK" \
        "Orchestration: ${detail} (attempt ${_saved_attempt}/${MAX_PIPELINE_ATTEMPTS:-5}, ${_ORCH_ELAPSED}s elapsed, ${_saved_calls} agent calls)" \
        "${_CURRENT_MILESTONE:-}"

    # Restore for metrics/logging if anything reads them after this
    _ORCH_ATTEMPT="$_saved_attempt"
    _ORCH_AGENT_CALLS="$_saved_calls"

    warn "State saved. Resume with: tekhton ${resume_flags} \"${TASK}\""
}
