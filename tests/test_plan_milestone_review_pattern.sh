#!/usr/bin/env bash
# Test: _display_milestone_summary pattern matching in lib/plan_milestone_review.sh
# Validates the ^#{2,4} regex pattern correctly matches 2-, 3-, and 4-hash milestone headings.
#
# Extracted from test_drift_resolution_verification.sh (Tests 7-12) with proper
# fixture isolation — no live file reads, TEKHTON_HOME-relative paths only.
set -euo pipefail

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS=0
FAIL=0

pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*"; FAIL=$((FAIL + 1)); }

# ============================================================
# Test 1: Verify the milestone pattern in lib/plan_milestone_review.sh
# The bug: OLD pattern was ^#{2,3} (2-3 hashes)
# The fix: NEW pattern is ^#{2,4} (2-4 hashes) to match plan_generate output
# ============================================================
PATTERN_LINE=$(grep -n '_display_milestone_summary' "${TEKHTON_HOME}/lib/plan_milestone_review.sh" | head -1 | cut -d: -f1)
if [ -z "$PATTERN_LINE" ]; then
    fail "Could not find _display_milestone_summary function"
else
    SEARCH_START=$((PATTERN_LINE))
    SEARCH_END=$((PATTERN_LINE + 100))
    GREP_PATTERN=$(sed -n "${SEARCH_START},${SEARCH_END}p" "${TEKHTON_HOME}/lib/plan_milestone_review.sh" | grep -o '\^#{2,4}' | head -1)
    if [ "$GREP_PATTERN" = '^#{2,4}' ]; then
        pass "lib/plan_milestone_review.sh _display_milestone_summary has corrected pattern (^#{2,4})"
    else
        fail "lib/plan_milestone_review.sh pattern should be ^#{2,4} but found: $GREP_PATTERN"
    fi
fi

# ============================================================
# Test 2: Pattern correctly matches 4-hash milestone headings
# ============================================================
TEST_CLAUDE_CONTENT="# Project Title
## Milestone 1: Setup
### Milestone 2: Build
#### Milestone 3: Test
Content here"

# Test the NEW pattern (what the fix installed)
NEW_MATCHES=$(echo "$TEST_CLAUDE_CONTENT" | grep -cE '^#{2,4} Milestone [0-9]+')
if [ "$NEW_MATCHES" -eq 3 ]; then
    pass "Pattern with fix ^#{2,4} correctly detects all 3 milestone types"
else
    fail "Pattern should match 3 milestones (2, 3, 4 hashes) but found $NEW_MATCHES"
fi

# Test the OLD pattern would have failed
OLD_MATCHES=$(echo "$TEST_CLAUDE_CONTENT" | grep -cE '^#{2,3} Milestone [0-9]+' || true)
if [ "$OLD_MATCHES" -eq 2 ]; then
    pass "Old pattern ^#{2,3} correctly misses the 4-hash milestone (regression confirmed)"
else
    fail "Old pattern should have found only 2 matches but found $OLD_MATCHES"
fi

# ============================================================
# Summary
# ============================================================
echo
echo "  Passed: ${PASS}  Failed: ${FAIL}"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
