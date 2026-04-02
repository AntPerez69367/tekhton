#!/usr/bin/env bash
# Test: Verify drift observations resolution
# Validates that both unresolved drift observations were properly resolved
# and logged in DRIFT_LOG.md with correct format.
set -euo pipefail

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$TEKHTON_HOME"

source "${TEKHTON_HOME}/lib/common.sh"
source "${TEKHTON_HOME}/lib/drift.sh"

FAIL=0

pass() {
    echo "PASS: $*"
}

fail() {
    echo "FAIL: $*"
    FAIL=1
}

assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" != "$actual" ]; then
        fail "$name — expected '$expected', got '$actual'"
    else
        pass "$name"
    fi
}

assert_file_contains() {
    local name="$1" file="$2" pattern="$3"
    if ! grep -q "$pattern" "$file" 2>/dev/null; then
        fail "$name — pattern '$pattern' not found in $file"
    else
        pass "$name"
    fi
}

assert_file_not_contains() {
    local name="$1" file="$2" pattern="$3"
    if grep -q "$pattern" "$file" 2>/dev/null; then
        fail "$name — unexpected pattern '$pattern' found in $file"
    else
        pass "$name"
    fi
}

# ============================================================
# Test 1: DRIFT_LOG.md exists
# ============================================================
if [ ! -f "${PROJECT_DIR}/DRIFT_LOG.md" ]; then
    fail "DRIFT_LOG.md file exists"
else
    pass "DRIFT_LOG.md file exists"
fi

# ============================================================
# Test 2: DRIFT_LOG has correct header structure
# ============================================================
assert_file_contains "drift log header" "${PROJECT_DIR}/DRIFT_LOG.md" "# Drift Log"
assert_file_contains "drift log metadata section" "${PROJECT_DIR}/DRIFT_LOG.md" "## Metadata"
assert_file_contains "drift log unresolved section" "${PROJECT_DIR}/DRIFT_LOG.md" "## Unresolved Observations"
assert_file_contains "drift log resolved section" "${PROJECT_DIR}/DRIFT_LOG.md" "## Resolved"

# ============================================================
# Test 3: Unresolved Observations section is empty
# ============================================================
# Extract the Unresolved Observations section and verify it contains only "(none)"
UNRESOLVED_SECTION=$(sed -n '/^## Unresolved Observations$/,/^## Resolved$/p' "${PROJECT_DIR}/DRIFT_LOG.md" | head -n 2)
if echo "$UNRESOLVED_SECTION" | grep -q "(none)"; then
    pass "Unresolved Observations section shows (none)"
else
    fail "Unresolved Observations section should show (none)"
fi

# ============================================================
# Test 4: First resolved observation is present (bash nameref issue)
# ============================================================
# This observation references lib/artifact_handler_ops.sh and bash 4.3+ nameref requirement
assert_file_contains \
    "nameref resolved observation" \
    "${PROJECT_DIR}/DRIFT_LOG.md" \
    "lib/artifact_handler_ops.sh"

assert_file_contains \
    "nameref resolved observation details" \
    "${PROJECT_DIR}/DRIFT_LOG.md" \
    "nameref.*bash 4.3"

assert_file_contains \
    "nameref resolved observation marked" \
    "${PROJECT_DIR}/DRIFT_LOG.md" \
    "\[RESOLVED 2026-04-02\].*lib/artifact_handler_ops.sh"

# ============================================================
# Test 5: Second resolved observation is present (noise entry cleared)
# ============================================================
# This observation notes that a noise entry was cleared
assert_file_contains \
    "noise entry cleared observation" \
    "${PROJECT_DIR}/DRIFT_LOG.md" \
    "Noise entry.*reviewer summary block.*cleared"

assert_file_contains \
    "noise entry resolved observation marked" \
    "${PROJECT_DIR}/DRIFT_LOG.md" \
    "\[RESOLVED 2026-04-02\].*Noise entry"

# ============================================================
# Test 6: Both resolved observations have RESOLVED timestamp
# ============================================================
RESOLVED_COUNT=$(grep -c "\[RESOLVED 2026-04-02\]" "${PROJECT_DIR}/DRIFT_LOG.md" || true)
assert_eq "two resolved observations with timestamps" "2" "$RESOLVED_COUNT"

# ============================================================
# Test 7: Resolved section is not empty
# ============================================================
RESOLVED_ITEMS=$(sed -n '/^## Resolved$/,$p' "${PROJECT_DIR}/DRIFT_LOG.md" | grep -c "^\-" || true)
if [ "$RESOLVED_ITEMS" -ge 2 ]; then
    pass "Resolved section contains at least 2 items"
else
    fail "Resolved section should contain at least 2 items, found $RESOLVED_ITEMS"
fi

# ============================================================
# Test 8: Metadata shows Last audit date
# ============================================================
assert_file_contains \
    "last audit metadata" \
    "${PROJECT_DIR}/DRIFT_LOG.md" \
    "Last audit: 2026-04-02"

# ============================================================
# Test 9: No unresolved entries remain in the file
# ============================================================
# Check that we don't have any actual observation entries in the Unresolved section
# (excluding the "(none)" line)
UNRESOLVED_SECTION=$(sed -n '/^## Unresolved Observations$/,/^## Resolved$/p' "${PROJECT_DIR}/DRIFT_LOG.md" || true)
if echo "$UNRESOLVED_SECTION" | grep -q "^-"; then
    fail "Found unresolved entries when there should be none"
else
    pass "No actual unresolved entries remain"
fi

# ============================================================
# Test 10: Drift log format is valid markdown
# ============================================================
# Basic check: no orphaned dashes, proper section structure
SECTION_COUNT=$(grep -c "^##" "${PROJECT_DIR}/DRIFT_LOG.md" || echo "0")
if [ "$SECTION_COUNT" -gt 0 ]; then
    pass "Drift log has valid markdown section headers ($SECTION_COUNT sections)"
else
    fail "Drift log markdown structure is invalid (no sections found)"
fi

# ============================================================
# Summary
# ============================================================
if [ "$FAIL" -eq 0 ]; then
    echo ""
    echo "All drift resolution verification tests passed."
    exit 0
else
    exit 1
fi
