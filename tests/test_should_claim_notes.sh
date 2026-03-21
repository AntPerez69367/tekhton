#!/usr/bin/env bash
# =============================================================================
# test_should_claim_notes.sh — Notes gating function tests
#
# Tests should_claim_notes() behavior:
# - Returns 0 (true) only when WITH_NOTES=true, HUMAN_MODE=true, or NOTES_FILTER set
# - Returns 1 (false) for all tasks when no flag is set (task text is never inspected)
# =============================================================================
set -euo pipefail

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# --- Minimal pipeline globals ------------------------------------------------
PROJECT_DIR="$TMPDIR"
WITH_NOTES=false
HUMAN_MODE=false
NOTES_FILTER=""

source "${TEKHTON_HOME}/lib/common.sh"
source "${TEKHTON_HOME}/lib/notes.sh"

FAIL=0

assert_success() {
    local name="$1"
    if should_claim_notes 2>/dev/null; then
        # Expected success
        return 0
    else
        echo "FAIL: $name — should_claim_notes returned 1 (false), expected 0 (true)"
        FAIL=1
    fi
}

assert_failure() {
    local name="$1"
    if should_claim_notes 2>/dev/null; then
        echo "FAIL: $name — should_claim_notes returned 0 (true), expected 1 (false)"
        FAIL=1
    else
        # Expected failure
        return 0
    fi
}

# =============================================================================
# Test 1: No flags set — always returns false regardless of task text
# =============================================================================

WITH_NOTES=false
HUMAN_MODE=false
NOTES_FILTER=""
assert_failure "1.1 unrelated task, no flags"
assert_failure "1.2 no flags at all"

# =============================================================================
# Test 2: Task text mentioning "human notes" does NOT trigger claiming
# =============================================================================

WITH_NOTES=false
HUMAN_MODE=false
NOTES_FILTER=""
# These previously returned true with task-text matching — now they must return false
assert_failure "2.1 task text is never inspected"
assert_failure "2.2 no task-text pattern matching"

# =============================================================================
# Test 3: WITH_NOTES=true forces claiming
# =============================================================================

WITH_NOTES=true
HUMAN_MODE=false
NOTES_FILTER=""
assert_success "3.1 WITH_NOTES=true forces claiming"

# =============================================================================
# Test 4: HUMAN_MODE=true forces claiming
# =============================================================================

WITH_NOTES=false
HUMAN_MODE=true
NOTES_FILTER=""
assert_success "4.1 HUMAN_MODE=true forces claiming"

# =============================================================================
# Test 5: NOTES_FILTER set forces claiming
# =============================================================================

WITH_NOTES=false
HUMAN_MODE=false
NOTES_FILTER="BUG"
assert_success "5.1 NOTES_FILTER=BUG forces claiming"

NOTES_FILTER="FEAT"
assert_success "5.2 NOTES_FILTER=FEAT forces claiming"

NOTES_FILTER="POLISH"
assert_success "5.3 NOTES_FILTER=POLISH forces claiming"

# =============================================================================
# Test 6: Toggling WITH_NOTES changes behavior
# =============================================================================

NOTES_FILTER=""
HUMAN_MODE=false

WITH_NOTES=false
assert_failure "6.1 flag off"

WITH_NOTES=true
assert_success "6.2 flag on"

WITH_NOTES=false
assert_failure "6.3 flag off again"

# =============================================================================
# Test 7: Toggling HUMAN_MODE changes behavior
# =============================================================================

WITH_NOTES=false
NOTES_FILTER=""

HUMAN_MODE=false
assert_failure "7.1 HUMAN_MODE off"

HUMAN_MODE=true
assert_success "7.2 HUMAN_MODE on"

HUMAN_MODE=false
assert_failure "7.3 HUMAN_MODE off again"

# =============================================================================
# Test 8: Multiple flags — OR logic
# =============================================================================

WITH_NOTES=true
HUMAN_MODE=true
NOTES_FILTER="BUG"
assert_success "8.1 all flags set — still returns true"

WITH_NOTES=false
HUMAN_MODE=false
NOTES_FILTER=""
assert_failure "8.2 all flags cleared — returns false"

# =============================================================================
# Test 9: Empty/unset variables handled safely
# =============================================================================

unset WITH_NOTES
unset HUMAN_MODE
NOTES_FILTER=""
assert_failure "9.1 unset flags default to false"

WITH_NOTES=false
HUMAN_MODE=false

# =============================================================================

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
