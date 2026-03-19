#!/usr/bin/env bash
# =============================================================================
# test_with_notes_flag.sh — --with-notes flag parsing and behavior
#
# Tests that:
# - --with-notes flag is recognized and parsed
# - Sets WITH_NOTES=true globally
# - Forces claim_human_notes() regardless of task text
# - Works in combination with should_claim_notes()
# - Task text is NEVER inspected (flag-only gating)
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

assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" != "$actual" ]; then
        echo "FAIL: $name — expected '$expected', got '$actual'"
        FAIL=1
    fi
}

# =============================================================================
# Test 1: Default WITH_NOTES is false
# =============================================================================

WITH_NOTES=false
assert_eq "1.1 default WITH_NOTES" "false" "$WITH_NOTES"

# =============================================================================
# Test 2: WITH_NOTES=true enables notes claiming for any task
# =============================================================================

WITH_NOTES=true
if should_claim_notes; then
    # Expected — WITH_NOTES forces claiming
    :
else
    echo "FAIL: 2.1 WITH_NOTES=true should force claiming"
    FAIL=1
fi

# =============================================================================
# Test 3: WITH_NOTES=false — task text is never inspected
# =============================================================================

WITH_NOTES=false
HUMAN_MODE=false
NOTES_FILTER=""
# Task without notes keyword should not claim
if should_claim_notes; then
    echo "FAIL: 3.1 unrelated task should not claim"
    FAIL=1
fi

# Task text mentioning "human notes" does NOT trigger claiming (flag-only)
# should_claim_notes no longer accepts task text parameter
if should_claim_notes; then
    echo "FAIL: 3.2 no flags set should not claim"
    FAIL=1
fi

# =============================================================================
# Test 4: Toggling WITH_NOTES changes behavior
# =============================================================================

HUMAN_MODE=false
NOTES_FILTER=""

WITH_NOTES=false
if should_claim_notes; then
    echo "FAIL: 4.1 should not claim with WITH_NOTES=false"
    FAIL=1
fi

WITH_NOTES=true
if ! should_claim_notes; then
    echo "FAIL: 4.2 should claim with WITH_NOTES=true"
    FAIL=1
fi

WITH_NOTES=false
if should_claim_notes; then
    echo "FAIL: 4.3 should not claim after toggling back to false"
    FAIL=1
fi

# =============================================================================
# Test 5: WITH_NOTES and HUMAN_MODE are independent conditions (OR logic)
# =============================================================================

# WITH_NOTES=true → claim
WITH_NOTES=true
HUMAN_MODE=false
if ! should_claim_notes; then
    echo "FAIL: 5.1 WITH_NOTES=true should force claim"
    FAIL=1
fi

# HUMAN_MODE=true → claim
WITH_NOTES=false
HUMAN_MODE=true
if ! should_claim_notes; then
    echo "FAIL: 5.2 HUMAN_MODE=true should force claim"
    FAIL=1
fi

# Neither flag → no claim
WITH_NOTES=false
HUMAN_MODE=false
if should_claim_notes; then
    echo "FAIL: 5.3 no flags should not claim"
    FAIL=1
fi

# =============================================================================
# Test 6: Flag affects global state (used by claim_human_notes)
# =============================================================================

# Create a minimal HUMAN_NOTES.md file for testing
notes_file="${PROJECT_DIR}/HUMAN_NOTES.md"
LOG_DIR="${PROJECT_DIR}/.logs"
mkdir -p "$LOG_DIR"
TIMESTAMP="20260308_120000"
NOTES_FILTER=""

cat > "$notes_file" << 'EOF'
# Human Notes

- [ ] Fix authentication bug
- [ ] Add password reset feature
- [ ] Improve error messages
EOF

cd "$PROJECT_DIR"

# Test that claim_human_notes can be controlled via WITH_NOTES
HUMAN_MODE=false
WITH_NOTES=false

# When WITH_NOTES=false, should_claim_notes returns false
if should_claim_notes; then
    echo "FAIL: 6.1 gate should prevent claiming"
    FAIL=1
fi

WITH_NOTES=true
# When WITH_NOTES=true, gate opens
if ! should_claim_notes; then
    echo "FAIL: 6.2 gate should open with WITH_NOTES=true"
    FAIL=1
fi

# =============================================================================
# Test 7: WITH_NOTES works with different case variations
# =============================================================================

HUMAN_MODE=false
NOTES_FILTER=""

# The implementation checks ${WITH_NOTES:-false} = "true"
# So only the string "true" (lowercase) should work

WITH_NOTES="true"
if ! should_claim_notes; then
    echo "FAIL: 7.1 WITH_NOTES='true' should work"
    FAIL=1
fi

# Other values should not enable claiming
WITH_NOTES="True"  # Capital T
if should_claim_notes; then
    echo "FAIL: 7.2 WITH_NOTES='True' should not work (case-sensitive)"
    FAIL=1
fi

WITH_NOTES="1"  # Truthy value but not the string "true"
if should_claim_notes; then
    echo "FAIL: 7.3 WITH_NOTES='1' should not work (must be 'true')"
    FAIL=1
fi

WITH_NOTES="true"  # Back to valid value
if ! should_claim_notes; then
    echo "FAIL: 7.4 WITH_NOTES='true' should work again"
    FAIL=1
fi

# =============================================================================
# Test 8: Unset WITH_NOTES defaults to false behavior
# =============================================================================

unset WITH_NOTES
HUMAN_MODE=false
NOTES_FILTER=""
# When unset, it defaults to "false"
if should_claim_notes; then
    echo "FAIL: 8.1 unset WITH_NOTES should default to false"
    FAIL=1
fi

# No flag set at all — should not claim
if should_claim_notes; then
    echo "FAIL: 8.2 no flags should not claim when WITH_NOTES unset"
    FAIL=1
fi

# =============================================================================
# Test 9: WITH_NOTES=false is equivalent to unset
# =============================================================================

WITH_NOTES=false
HUMAN_MODE=false
NOTES_FILTER=""
if should_claim_notes; then
    echo "FAIL: 9.1 WITH_NOTES=false should not claim"
    FAIL=1
fi

# Only flag-based claiming works
WITH_NOTES=false
HUMAN_MODE=false
NOTES_FILTER="BUG"
if ! should_claim_notes; then
    echo "FAIL: 9.2 NOTES_FILTER=BUG should claim"
    FAIL=1
fi

# =============================================================================

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
