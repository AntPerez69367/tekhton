#!/usr/bin/env bash
# Tests for TUI stage guard logic (non-blocking note 5)
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TEKHTON_HOME="$(cd "$SCRIPT_DIR/.." && pwd)"

source "${TEKHTON_HOME}/lib/common.sh"
source "${TEKHTON_HOME}/lib/pipeline_order.sh"

# Test should_run_stage with standard order
_test_standard_order_stages() {
    export PIPELINE_ORDER="standard"

    # When no START_AT is given, all stages should run
    if should_run_stage "coder" ""; then
        :
    else
        echo "FAIL: coder should run with empty START_AT"
        return 1
    fi

    if should_run_stage "review" ""; then
        :
    else
        echo "FAIL: review should run with empty START_AT"
        return 1
    fi

    echo "PASS: Standard order stages run with empty START_AT"
    return 0
}

# Test should_run_stage with --start-at coder
_test_start_at_coder() {
    export PIPELINE_ORDER="standard"

    # When START_AT is "coder", stages before coder (scout) should not run
    # but coder and after should
    if should_run_stage "scout" "coder"; then
        echo "FAIL: scout should not run when --start-at coder"
        return 1
    fi

    if should_run_stage "coder" "coder"; then
        :
    else
        echo "FAIL: coder should run when --start-at coder"
        return 1
    fi

    if should_run_stage "review" "coder"; then
        :
    else
        echo "FAIL: review should run when --start-at coder"
        return 1
    fi

    echo "PASS: --start-at coder skips upstream stages"
    return 0
}

# Test should_run_stage with --start-at review
_test_start_at_review() {
    export PIPELINE_ORDER="standard"

    # When START_AT is "review", coder should not run
    if should_run_stage "coder" "review"; then
        echo "FAIL: coder should not run when --start-at review"
        return 1
    fi

    if should_run_stage "review" "review"; then
        :
    else
        echo "FAIL: review should run when --start-at review"
        return 1
    fi

    if should_run_stage "test_verify" "review"; then
        :
    else
        echo "FAIL: test_verify should run when --start-at review"
        return 1
    fi

    echo "PASS: --start-at review skips coder and security"
    return 0
}

# Test should_run_stage with test_first order
_test_test_first_order() {
    export PIPELINE_ORDER="test_first"

    # In test_first order: scout test_write coder security review test_verify
    # When starting at coder, test_write should not run
    if should_run_stage "test_write" "coder"; then
        echo "FAIL: test_write should not run when --start-at coder in test_first"
        return 1
    fi

    if should_run_stage "coder" "coder"; then
        :
    else
        echo "FAIL: coder should run when --start-at coder"
        return 1
    fi

    echo "PASS: test_first order --start-at coder works correctly"
    return 0
}

# Test TUI guard logic: _tui_will_run_stage should match should_run_stage
_test_tui_guard_logic() {
    # Simulate the guard logic from tekhton.sh lines 2343-2346
    local _stage_name="coder"
    local START_AT="review"
    local _tui_will_run_stage="false"

    export PIPELINE_ORDER="standard"

    if should_run_stage "$_stage_name" "$START_AT"; then
        _tui_will_run_stage="true"
    fi

    # Since START_AT is "review" and stage is "coder",
    # should_run_stage should return false
    if [[ "$_tui_will_run_stage" == "false" ]]; then
        echo "PASS: TUI guard correctly identifies skipped stage"
        return 0
    else
        echo "FAIL: TUI guard should be false for skipped stage"
        return 1
    fi
}

# Test TUI guard for running stage
_test_tui_guard_for_running_stage() {
    # When we're at review and checking review stage
    local _stage_name="review"
    local START_AT="review"
    local _tui_will_run_stage="false"

    export PIPELINE_ORDER="standard"

    if should_run_stage "$_stage_name" "$START_AT"; then
        _tui_will_run_stage="true"
    fi

    if [[ "$_tui_will_run_stage" == "true" ]]; then
        echo "PASS: TUI guard correctly identifies running stage"
        return 0
    else
        echo "FAIL: TUI guard should be true for running stage"
        return 1
    fi
}

_test_standard_order_stages || exit 1
_test_start_at_coder || exit 1
_test_start_at_review || exit 1
_test_test_first_order || exit 1
_test_tui_guard_logic || exit 1
_test_tui_guard_for_running_stage || exit 1

echo "All TUI stage guard tests passed"
exit 0
