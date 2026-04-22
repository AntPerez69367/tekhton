#!/usr/bin/env bash
# =============================================================================
# test_tui_ops_idle_ordering.sh — Verify run_op sets idle before tui_substage_end
#
# Tests that run_op (M115 fix) sets _TUI_AGENT_STATUS="idle" before calling
# tui_substage_end so the substage-end write already carries the final idle
# status, avoiding transitional "Working…" frames.
# =============================================================================

set -euo pipefail

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$(mktemp -d)"
trap 'rm -rf "$PROJECT_DIR"' EXIT

source "${TEKHTON_HOME}/lib/common.sh"
source "${TEKHTON_HOME}/lib/output_format.sh"
source "${TEKHTON_HOME}/lib/tui.sh"

pass() { printf "✓ %s\n" "$@"; }
fail() { printf "✗ %s\n" "$@"; exit 1; }

# Test: run_op sets idle before substage_end
test_run_op_idle_ordering() {
    local status_snapshots=()

    # Mock tui_substage_begin and tui_substage_end to capture status at each point
    local _idle_before_end="false"

    tui_substage_begin() {
        # Record status when substage begins
        [[ "$_TUI_AGENT_STATUS" == "working" ]] || fail "status not 'working' at substage_begin"
        return 0
    }

    tui_substage_end() {
        # Capture whether idle was already set
        if [[ "$_TUI_AGENT_STATUS" == "idle" ]]; then
            _idle_before_end="true"
        fi
        return 0
    }

    _tui_write_status() { return 0; }
    _tui_should_activate() { return 0; }

    # Activate TUI
    _TUI_ACTIVE="true"

    # Mock a successful command
    run_op "test_label" true

    # Verify idle was set before tui_substage_end
    if [[ "$_idle_before_end" == "true" ]]; then
        pass "run_op sets idle before tui_substage_end"
    else
        fail "run_op does not set idle before tui_substage_end"
    fi
}

# Test: run_op passes through when TUI inactive
test_run_op_passthrough_inactive() {
    _TUI_ACTIVE="false"

    local cmd_ran="false"

    test_fn() { cmd_ran="true"; }

    run_op "test_label" test_fn

    if [[ "$cmd_ran" == "true" ]]; then
        pass "run_op passes through when TUI_ACTIVE=false"
    else
        fail "run_op did not pass through"
    fi
}

# Test: run_op preserves command exit code on success
test_run_op_exit_code_success() {
    _TUI_ACTIVE="true"

    # Mock the substage API
    tui_substage_begin() { return 0; }
    tui_substage_end() { return 0; }
    _tui_write_status() { return 0; }

    # Run a command that succeeds
    local exit_code=0
    run_op "test" true || exit_code=$?

    if [[ "$exit_code" -eq 0 ]]; then
        pass "run_op returns 0 on successful command"
    else
        fail "run_op did not return 0 on success, got $exit_code"
    fi
}

# Test: run_op preserves command exit code on failure
test_run_op_exit_code_failure() {
    _TUI_ACTIVE="true"

    # Mock the substage API
    tui_substage_begin() { return 0; }
    tui_substage_end() { return 0; }
    _tui_write_status() { return 0; }

    # Run a command that fails
    local exit_code=0
    run_op "test" false || exit_code=$?

    if [[ "$exit_code" -ne 0 ]]; then
        pass "run_op returns non-zero on failed command"
    else
        fail "run_op did not return non-zero on failure"
    fi
}

# Test: run_op writes status after command completes (sanity check)
test_run_op_write_occurs_after_command() {
    _TUI_ACTIVE="true"

    local write_count=0

    tui_substage_begin() { return 0; }
    tui_substage_end() { return 0; }
    _tui_write_status() {
        write_count=$((write_count + 1))
        return 0
    }

    run_op "test" true

    if [[ "$write_count" -ge 1 ]]; then
        pass "run_op writes status after command completes"
    else
        fail "no status writes occurred after command"
    fi
}

test_run_op_idle_ordering
test_run_op_passthrough_inactive
test_run_op_exit_code_success
test_run_op_exit_code_failure
test_run_op_write_occurs_after_command

pass "All run_op idle ordering tests passed"
