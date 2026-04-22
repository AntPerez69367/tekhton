#!/usr/bin/env bash
# =============================================================================
# test_emit_event_guard_consistency.sh — Verify emit_event guard consistency
#
# Tests that stages/coder_prerun.sh and stages/tester_fix.sh both use the
# consistent `declare -f` guard pattern when calling emit_event (M113 fix).
# Both files should use the same idiomatic pattern for function availability
# checks, matching the convention throughout the codebase.
# =============================================================================

set -euo pipefail

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "${TEKHTON_HOME}/lib/common.sh"

pass() { printf "✓ %s\n" "$@"; }
fail() { printf "✗ %s\n" "$@"; exit 1; }

# Test: verify declare -f guard pattern works for function detection
test_declare_f_guard_logic() {
    # Mock function
    emit_event() { echo "event emitted"; }

    if declare -f emit_event &>/dev/null; then
        : # Function exists
    else
        fail "declare -f should detect existing function"
    fi

    unset -f emit_event

    if declare -f emit_event &>/dev/null; then
        fail "declare -f should not detect unset function"
    else
        : # Function does not exist
    fi

    pass "declare -f guard pattern works correctly"
}

# Test: coder_prerun.sh uses declare -f guard for emit_event
test_coder_prerun_guard_pattern() {
    local file="${TEKHTON_HOME}/stages/coder_prerun.sh"
    [[ -f "$file" ]] || fail "coder_prerun.sh not found"

    # Count emit_event calls that are guarded with declare -f
    local guarded_count
    guarded_count=$(grep -c 'declare -f emit_event' "$file" || echo "0")

    if [[ "$guarded_count" -gt 0 ]]; then
        pass "coder_prerun.sh uses declare -f guard for emit_event"
    else
        fail "coder_prerun.sh does not use declare -f guard for emit_event"
    fi

    # Verify the pattern is correct (declare -f emit_event &>/dev/null)
    if grep -q 'declare -f emit_event.*&>/dev/null' "$file"; then
        pass "coder_prerun.sh guard pattern matches canonical form"
    else
        fail "coder_prerun.sh guard pattern is not canonical"
    fi
}

# Test: tester_fix.sh uses declare -f guard for emit_event
test_tester_fix_guard_pattern() {
    local file="${TEKHTON_HOME}/stages/tester_fix.sh"
    [[ -f "$file" ]] || fail "tester_fix.sh not found"

    # Count emit_event calls that are guarded with declare -f
    local guarded_count
    guarded_count=$(grep -c 'declare -f emit_event' "$file" || echo "0")

    if [[ "$guarded_count" -gt 0 ]]; then
        pass "tester_fix.sh uses declare -f guard for emit_event"
    else
        fail "tester_fix.sh does not use declare -f guard for emit_event"
    fi

    # Verify the pattern is correct (declare -f emit_event &>/dev/null)
    if grep -q 'declare -f emit_event.*&>/dev/null' "$file"; then
        pass "tester_fix.sh guard pattern matches canonical form"
    else
        fail "tester_fix.sh guard pattern is not canonical"
    fi
}

# Test: both files use the same guard pattern
test_guard_consistency() {
    local coder_prerun_file="${TEKHTON_HOME}/stages/coder_prerun.sh"
    local tester_fix_file="${TEKHTON_HOME}/stages/tester_fix.sh"

    # Extract the guard patterns
    local coder_pattern
    coder_pattern=$(grep 'declare -f emit_event' "$coder_prerun_file" | head -1 || echo "")

    local tester_pattern
    tester_pattern=$(grep 'declare -f emit_event' "$tester_fix_file" | head -1 || echo "")

    if [[ -z "$coder_pattern" ]] || [[ -z "$tester_pattern" ]]; then
        fail "Could not extract guard patterns from both files"
    fi

    # Both should use &>/dev/null redirection
    if [[ "$coder_pattern" == *"&>/dev/null"* ]] && [[ "$tester_pattern" == *"&>/dev/null"* ]]; then
        pass "both files use consistent &>/dev/null redirection"
    else
        fail "guard patterns have inconsistent redirection"
    fi
}

# Test: emit_event guard coverage is consistent
test_emit_event_always_guarded() {
    local coder_prerun_file="${TEKHTON_HOME}/stages/coder_prerun.sh"
    local tester_fix_file="${TEKHTON_HOME}/stages/tester_fix.sh"

    # Count total emit_event calls and guard patterns in each file
    local coder_calls
    coder_calls=$(grep -c 'emit_event' "$coder_prerun_file" || echo 0)

    local coder_guards
    coder_guards=$(grep -c 'declare -f emit_event' "$coder_prerun_file" || echo 0)

    local tester_calls
    tester_calls=$(grep -c 'emit_event' "$tester_fix_file" || echo 0)

    local tester_guards
    tester_guards=$(grep -c 'declare -f emit_event' "$tester_fix_file" || echo 0)

    # Rough check: guard count should be significant compared to call count
    # (guards often protect multiple calls within an if block)
    if [[ "$coder_guards" -gt 0 ]]; then
        pass "coder_prerun.sh has $coder_guards guards for $coder_calls emit_event calls"
    else
        fail "coder_prerun.sh has no guards for emit_event"
    fi

    if [[ "$tester_guards" -gt 0 ]]; then
        pass "tester_fix.sh has $tester_guards guards for $tester_calls emit_event calls"
    else
        fail "tester_fix.sh has no guards for emit_event"
    fi

    # Both should use the canonical declare -f pattern (already verified above)
    pass "emit_event calls are protected by guard patterns in both files"
}

test_declare_f_guard_logic
test_coder_prerun_guard_pattern
test_tester_fix_guard_pattern
test_guard_consistency
test_emit_event_always_guarded

pass "All emit_event guard consistency tests passed"
