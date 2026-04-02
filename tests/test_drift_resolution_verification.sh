#!/usr/bin/env bash
# Test: Verify drift log structure and resolution state
# Validates that DRIFT_LOG.md has correct format and no unresolved observations.
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

assert_file_contains() {
    local name="$1" file="$2" pattern="$3"
    if ! grep -q "$pattern" "$file" 2>/dev/null; then
        fail "$name — pattern '$pattern' not found in $file"
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
UNRESOLVED_SECTION=$(sed -n '/^## Unresolved Observations$/,/^## Resolved$/p' "${PROJECT_DIR}/DRIFT_LOG.md" | head -n 2)
if echo "$UNRESOLVED_SECTION" | grep -q "(none)"; then
    pass "Unresolved Observations section shows (none)"
else
    fail "Unresolved Observations section should show (none)"
fi

# ============================================================
# Test 4: Metadata shows Last audit date
# ============================================================
assert_file_contains \
    "last audit metadata" \
    "${PROJECT_DIR}/DRIFT_LOG.md" \
    "Last audit:"

# ============================================================
# Test 5: No unresolved entries remain in the file
# ============================================================
UNRESOLVED_SECTION=$(sed -n '/^## Unresolved Observations$/,/^## Resolved$/p' "${PROJECT_DIR}/DRIFT_LOG.md" || true)
if echo "$UNRESOLVED_SECTION" | grep -q "^-"; then
    fail "Found unresolved entries when there should be none"
else
    pass "No actual unresolved entries remain"
fi

# ============================================================
# Test 6: Drift log format is valid markdown
# ============================================================
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
