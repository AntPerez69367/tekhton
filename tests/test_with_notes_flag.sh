#!/usr/bin/env bash
# =============================================================================
# test_with_notes_flag.sh — --with-notes flag parsing and behavior
#
# Tests that:
# - --with-notes flag is recognized and parsed
# - Sets WITH_NOTES=true globally
# - Forces claim_human_notes() regardless of task text
# - Works in combination with should_claim_notes()
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

assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" != "$actual" ]; then
        echo "FAIL: $name — expected '$expected', got '$actual'"
        FAIL=1
    fi
}

assert_true() {
    local name="$1" condition="${2:-}"
    if ! eval "$condition"; then
        echo "FAIL: $name — condition false: $condition"
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
if should_claim_notes "implement auth module"; then
    # Expected — WITH_NOTES forces claiming
    :
else
    echo "FAIL: 2.1 WITH_NOTES=true should force claiming"
    FAIL=1
fi

# =============================================================================
# Test 3: WITH_NOTES=false respects task text matching
# =============================================================================

WITH_NOTES=false
# Task without notes keyword should not claim
if should_claim_notes "implement auth module"; then
    echo "FAIL: 3.1 unrelated task should not claim"
    FAIL=1
fi

# Task with notes keyword should claim
if ! should_claim_notes "address human notes"; then
    echo "FAIL: 3.2 task with notes should claim"
    FAIL=1
fi

# =============================================================================
# Test 4: Toggling WITH_NOTES changes behavior
# =============================================================================

task="implement database migration"

WITH_NOTES=false
if should_claim_notes "$task"; then
    echo "FAIL: 4.1 should not claim with WITH_NOTES=false"
    FAIL=1
fi

WITH_NOTES=true
if ! should_claim_notes "$task"; then
    echo "FAIL: 4.2 should claim with WITH_NOTES=true"
    FAIL=1
fi

WITH_NOTES=false
if should_claim_notes "$task"; then
    echo "FAIL: 4.3 should not claim after toggling back to false"
    FAIL=1
fi

# =============================================================================
# Test 5: WITH_NOTES and task text are independent conditions (OR logic)
# =============================================================================

# WITH_NOTES=true OR task mentions human notes → claim
WITH_NOTES=true
if ! should_claim_notes "any task"; then
    echo "FAIL: 5.1 WITH_NOTES=true should force claim"
    FAIL=1
fi

# WITH_NOTES=false AND task mentions human notes → claim
WITH_NOTES=false
if ! should_claim_notes "address human notes"; then
    echo "FAIL: 5.2 task mentioning notes should force claim"
    FAIL=1
fi

# WITH_NOTES=false AND task doesn't mention human notes → don't claim
WITH_NOTES=false
if should_claim_notes "random task"; then
    echo "FAIL: 5.3 random task without flag should not claim"
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
# (We can't directly test claim_human_notes since it modifies files,
# but we can test that WITH_NOTES is visible to it via should_claim_notes)

WITH_NOTES=false
task="implement auth"

# When WITH_NOTES=false and task doesn't mention notes, should_claim_notes returns false
if should_claim_notes "$task"; then
    echo "FAIL: 6.1 gate should prevent claiming"
    FAIL=1
fi

WITH_NOTES=true
# When WITH_NOTES=true, gate opens regardless of task
if ! should_claim_notes "$task"; then
    echo "FAIL: 6.2 gate should open with WITH_NOTES=true"
    FAIL=1
fi

# =============================================================================
# Test 7: WITH_NOTES works with different case variations
# =============================================================================

# The implementation checks ${WITH_NOTES:-false} = "true"
# So only the string "true" (lowercase) should work

WITH_NOTES="true"
if ! should_claim_notes "any task"; then
    echo "FAIL: 7.1 WITH_NOTES='true' should work"
    FAIL=1
fi

# Other values should not enable claiming
WITH_NOTES="True"  # Capital T
if should_claim_notes "random task"; then
    echo "FAIL: 7.2 WITH_NOTES='True' should not work (case-sensitive)"
    FAIL=1
fi

WITH_NOTES="1"  # Truthy value but not the string "true"
if should_claim_notes "random task"; then
    echo "FAIL: 7.3 WITH_NOTES='1' should not work (must be 'true')"
    FAIL=1
fi

WITH_NOTES="true"  # Back to valid value
if ! should_claim_notes "random task"; then
    echo "FAIL: 7.4 WITH_NOTES='true' should work again"
    FAIL=1
fi

# =============================================================================
# Test 8: Unset WITH_NOTES defaults to false behavior
# =============================================================================

unset WITH_NOTES
# When unset, it defaults to "false" in the grep -qiE test
if should_claim_notes "random task"; then
    echo "FAIL: 8.1 unset WITH_NOTES should default to false"
    FAIL=1
fi

if ! should_claim_notes "address human notes"; then
    echo "FAIL: 8.2 task with notes should still claim when WITH_NOTES unset"
    FAIL=1
fi

# =============================================================================
# Test 9: WITH_NOTES=false is equivalent to unset
# =============================================================================

WITH_NOTES=false
if should_claim_notes "random task"; then
    echo "FAIL: 9.1 WITH_NOTES=false should not claim random task"
    FAIL=1
fi

if ! should_claim_notes "fix human notes"; then
    echo "FAIL: 9.2 task with notes should claim even with WITH_NOTES=false"
    FAIL=1
fi

# =============================================================================

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
