#!/usr/bin/env bash
# Test: _route_audit_verdict handles unknown verdicts with catch-all case (M95 Note 1)
set -euo pipefail

TEKHTON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$(mktemp -d)"
trap "rm -rf $PROJECT_DIR" EXIT

# Source required libraries
source "$TEKHTON_DIR/lib/common.sh"

# Create mock TEST_AUDIT_REPORT_FILE
export TEST_AUDIT_REPORT_FILE="$PROJECT_DIR/test_audit_report.md"
export NON_BLOCKING_LOG_FILE="$PROJECT_DIR/NON_BLOCKING_LOG.md"

# Source the function under test
source "$TEKHTON_DIR/lib/test_audit_verdict.sh"

# Test 1: Unknown verdict should warn and return 0
test_unknown_verdict_catch_all() {
    local verdict="INVALID_VERDICT"
    local output
    local exit_code

    # Capture stderr and stdout, preserve exit code
    output=$(_route_audit_verdict "$verdict" 2>&1)
    exit_code=$?

    # Should return 0
    if [[ $exit_code -ne 0 ]]; then
        echo "FAIL: _route_audit_verdict returned $exit_code instead of 0 for unknown verdict"
        return 1
    fi

    # Should emit warning about unknown verdict
    if ! echo "$output" | grep -q "Unknown test audit verdict"; then
        echo "FAIL: _route_audit_verdict did not warn about unknown verdict"
        echo "Output was: $output"
        return 1
    fi

    # Should explicitly mention 'treating as PASS'
    if ! echo "$output" | grep -q "treating as PASS"; then
        echo "FAIL: _route_audit_verdict warning did not mention 'treating as PASS'"
        echo "Output was: $output"
        return 1
    fi

    return 0
}

# Test 2: Known verdict PASS should still work
test_known_verdict_pass() {
    local verdict="PASS"
    local output
    local exit_code

    output=$(_route_audit_verdict "$verdict" 2>&1)
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        echo "FAIL: _route_audit_verdict returned $exit_code for PASS verdict"
        return 1
    fi

    if ! echo "$output" | grep -q "Test audit passed"; then
        echo "FAIL: _route_audit_verdict did not emit success message for PASS"
        echo "Output was: $output"
        return 1
    fi

    return 0
}

# Test 3: Known verdict CONCERNS should still work
test_known_verdict_concerns() {
    local verdict="CONCERNS"
    local output
    local exit_code

    output=$(_route_audit_verdict "$verdict" 2>&1)
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        echo "FAIL: _route_audit_verdict returned $exit_code for CONCERNS verdict"
        return 1
    fi

    if ! echo "$output" | grep -q "concerns"; then
        echo "FAIL: _route_audit_verdict did not emit concerns message"
        echo "Output was: $output"
        return 1
    fi

    return 0
}

# Test 4: Known verdict NEEDS_WORK should return 1
test_known_verdict_needs_work() {
    local verdict="NEEDS_WORK"
    local output
    local exit_code

    output=$(_route_audit_verdict "$verdict" 2>&1) || exit_code=$?
    [[ -z "${exit_code:-}" ]] && exit_code=$?

    if [[ $exit_code -ne 1 ]]; then
        echo "FAIL: _route_audit_verdict returned $exit_code instead of 1 for NEEDS_WORK"
        return 1
    fi

    if ! echo "$output" | grep -q "NEEDS_WORK"; then
        echo "FAIL: _route_audit_verdict did not emit NEEDS_WORK message"
        echo "Output was: $output"
        return 1
    fi

    return 0
}

# Run all tests
if test_unknown_verdict_catch_all && \
   test_known_verdict_pass && \
   test_known_verdict_concerns && \
   test_known_verdict_needs_work; then
    echo "PASS"
    exit 0
else
    echo "FAIL"
    exit 1
fi
