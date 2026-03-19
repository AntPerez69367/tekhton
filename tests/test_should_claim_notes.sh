#!/usr/bin/env bash
# =============================================================================
# test_should_claim_notes.sh — Notes gating function tests
#
# Tests should_claim_notes() behavior:
# - Returns 0 (true) when task matches patterns or WITH_NOTES=true
# - Returns 1 (false) for unrelated tasks
# - Patterns: [Hh]uman.?[Nn]otes, HUMAN_NOTES (case-insensitive)
# =============================================================================
set -euo pipefail

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# --- Minimal pipeline globals ------------------------------------------------
PROJECT_DIR="$TMPDIR"
WITH_NOTES=false

source "${TEKHTON_HOME}/lib/common.sh"
source "${TEKHTON_HOME}/lib/notes.sh"

FAIL=0

assert_success() {
    local name="$1" task_text="$2"
    if should_claim_notes "$task_text" 2>/dev/null; then
        # Expected success
        return 0
    else
        echo "FAIL: $name — should_claim_notes returned 1 (false), expected 0 (true)"
        FAIL=1
    fi
}

assert_failure() {
    local name="$1" task_text="$2"
    if should_claim_notes "$task_text" 2>/dev/null; then
        echo "FAIL: $name — should_claim_notes returned 0 (true), expected 1 (false)"
        FAIL=1
    else
        # Expected failure
        return 0
    fi
}

# =============================================================================
# Test 1: Unrelated task returns false
# =============================================================================

WITH_NOTES=false
assert_failure "1.1 unrelated task" "implement auth module"
assert_failure "1.2 unrelated task 2" "fix database connection"
assert_failure "1.3 unrelated task 3" "refactor controller logic"

# =============================================================================
# Test 2: Task mentioning "human notes" (case-insensitive) returns true
# =============================================================================

WITH_NOTES=false
assert_success "2.1 'human notes' lowercase" "address human notes"
assert_success "2.2 'human notes' uppercase" "address HUMAN NOTES"
assert_success "2.3 'Human Notes' mixed case" "address Human Notes"
assert_success "2.4 'HuMaN NoTeS' mixed case" "address HuMaN NoTeS"

# =============================================================================
# Test 3: Task mentioning "HUMAN_NOTES" constant returns true
# =============================================================================

WITH_NOTES=false
assert_success "3.1 HUMAN_NOTES constant" "process HUMAN_NOTES items"
assert_success "3.2 HUMAN_NOTES in context" "fix items from HUMAN_NOTES"
assert_success "3.3 HUMAN_NOTES at end" "resolve all HUMAN_NOTES"

# =============================================================================
# Test 4: Flexible spacing between "human" and "notes"
# =============================================================================

WITH_NOTES=false
assert_success "4.1 'human notes' with space" "fix human notes"
assert_success "4.2 'human-notes' with dash" "fix human-notes"
assert_success "4.3 'human_notes' with underscore" "fix human_notes"

# =============================================================================
# Test 5: WITH_NOTES=true overrides task text (global flag)
# =============================================================================

WITH_NOTES=true
assert_success "5.1 unrelated task with flag" "implement auth module"
assert_success "5.2 another unrelated task with flag" "fix database connection"
assert_success "5.3 completely random task with flag" "add feature X"

# =============================================================================
# Test 6: WITH_NOTES=false resets override
# =============================================================================

WITH_NOTES=false
assert_failure "6.1 flag disabled returns to normal" "implement auth module"

# =============================================================================
# Test 7: Empty task text returns false
# =============================================================================

WITH_NOTES=false
assert_failure "7.1 empty string" ""

# =============================================================================
# Test 8: Partial matches in longer text
# =============================================================================

WITH_NOTES=false
assert_success "8.1 'human notes' in longer text" "this task requires addressing human notes for the system"
assert_success "8.2 HUMAN_NOTES in longer text" "resolve HUMAN_NOTES from playtesting feedback"

# =============================================================================
# Test 9: Word boundaries (should NOT match partial words)
# =============================================================================

WITH_NOTES=false
# "humanoid" should NOT match "human", "notess" should NOT match "notes"
# The regex is flexible on spacing but uses word boundaries implicitly via grep
# This is a sanity check that we're not matching substrings incorrectly
assert_failure "9.1 'humanoid' (not human)" "fix the humanoid creature behavior"

# =============================================================================
# Test 10: Multiple flag toggles in same test
# =============================================================================

WITH_NOTES=false
assert_failure "10.1 flag off" "implement auth module"

WITH_NOTES=true
assert_success "10.2 flag on" "implement auth module"

WITH_NOTES=false
assert_failure "10.3 flag off again" "implement auth module"

# =============================================================================

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
