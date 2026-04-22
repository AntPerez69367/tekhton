#!/usr/bin/env bash
# =============================================================================
# test_tui_substage_unused_args.sh — Verify substage unused arg bindings
#
# Tests that tui_substage_begin and tui_substage_end correctly bind their
# unused positional parameters (_model, _label, _verdict) without breaking
# function behavior. These args are accepted for call-site symmetry but not
# used (M113).
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

# Test: tui_substage_begin accepts and ignores MODEL arg
test_substage_begin_model_arg() {
    _TUI_ACTIVE="true"
    _tui_write_status() { return 0; }

    # Should not error even with model arg
    tui_substage_begin "scout" "claude-opus-4-7" || fail "tui_substage_begin failed with model arg"

    # Verify substage label was set
    if [[ "$_TUI_CURRENT_SUBSTAGE_LABEL" == "scout" ]]; then
        pass "tui_substage_begin accepts and ignores MODEL argument"
    else
        fail "substage label not set correctly"
    fi
}

# Test: tui_substage_begin works without MODEL arg
test_substage_begin_no_model() {
    _TUI_ACTIVE="true"
    _tui_write_status() { return 0; }
    _TUI_CURRENT_SUBSTAGE_LABEL=""

    tui_substage_begin "rework" || fail "tui_substage_begin failed without model arg"

    if [[ "$_TUI_CURRENT_SUBSTAGE_LABEL" == "rework" ]]; then
        pass "tui_substage_begin works without MODEL argument"
    else
        fail "substage label not set"
    fi
}

# Test: tui_substage_end accepts LABEL and VERDICT args
test_substage_end_with_args() {
    _TUI_ACTIVE="true"
    _TUI_CURRENT_SUBSTAGE_LABEL="scout"
    _TUI_CURRENT_SUBSTAGE_START_TS=$(date +%s)
    _tui_write_status() { return 0; }

    # Should not error with label and verdict args
    tui_substage_end "scout" "PASS" || fail "tui_substage_end failed with label/verdict args"

    # Verify substage was cleared
    if [[ -z "$_TUI_CURRENT_SUBSTAGE_LABEL" ]]; then
        pass "tui_substage_end clears substage with LABEL and VERDICT args"
    else
        fail "substage label not cleared"
    fi
}

# Test: tui_substage_end works without extra args
test_substage_end_no_args() {
    _TUI_ACTIVE="true"
    _TUI_CURRENT_SUBSTAGE_LABEL="rework"
    _TUI_CURRENT_SUBSTAGE_START_TS=$(date +%s)
    _tui_write_status() { return 0; }

    tui_substage_end || fail "tui_substage_end failed without args"

    if [[ -z "$_TUI_CURRENT_SUBSTAGE_LABEL" ]]; then
        pass "tui_substage_end works without LABEL and VERDICT args"
    else
        fail "substage label not cleared"
    fi
}

# Test: unused args don't pollute global state
test_unused_args_no_global_pollution() {
    _TUI_ACTIVE="true"
    _tui_write_status() { return 0; }

    # Set a global variable and verify it's not overwritten by arg binding
    local test_var="original"

    # Call with args that might shadow a variable if not handled correctly
    tui_substage_begin "scout" "model1"
    tui_substage_end "scout" "PASS"

    if [[ "$test_var" == "original" ]]; then
        pass "unused args do not pollute global scope"
    else
        fail "test_var was modified: $test_var"
    fi
}

# Test: multiple calls with different args work correctly
test_multiple_calls_different_args() {
    _TUI_ACTIVE="true"
    _tui_write_status() { return 0; }

    local results=()

    # First substage
    tui_substage_begin "scout" "claude-opus-4-7"
    [[ "$_TUI_CURRENT_SUBSTAGE_LABEL" == "scout" ]] && results+=("1")
    tui_substage_end "scout" "PASS"
    [[ -z "$_TUI_CURRENT_SUBSTAGE_LABEL" ]] && results+=("2")

    # Second substage
    tui_substage_begin "rework" "claude-sonnet-4-6"
    [[ "$_TUI_CURRENT_SUBSTAGE_LABEL" == "rework" ]] && results+=("3")
    tui_substage_end "rework" "FAIL"
    [[ -z "$_TUI_CURRENT_SUBSTAGE_LABEL" ]] && results+=("4")

    if [[ ${#results[@]} -eq 4 ]]; then
        pass "multiple substage calls with different args work correctly"
    else
        fail "not all checks passed: ${results[*]}"
    fi
}

# Test: TUI inactive passthrough
test_substage_inactive_passthrough() {
    _TUI_ACTIVE="false"

    # These should be no-ops when TUI is inactive
    local result="unchanged"
    _TUI_CURRENT_SUBSTAGE_LABEL="unchanged"

    tui_substage_begin "test" "model"
    tui_substage_end "test" "PASS"

    if [[ "$_TUI_CURRENT_SUBSTAGE_LABEL" == "unchanged" ]]; then
        pass "substage functions are no-ops when TUI inactive"
    else
        fail "substage functions ran when TUI was inactive"
    fi
}

test_substage_begin_model_arg
test_substage_begin_no_model
test_substage_end_with_args
test_substage_end_no_args
test_unused_args_no_global_pollution
test_multiple_calls_different_args
test_substage_inactive_passthrough

pass "All substage unused arg tests passed"
