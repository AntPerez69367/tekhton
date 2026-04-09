#!/usr/bin/env bash
# Test: templates/coder.md has the correct CODER_SUMMARY.md skeleton structure
set -euo pipefail

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODER_ROLE="${TEKHTON_HOME}/templates/coder.md"

PASS=0
FAIL=0

check() {
    local desc="$1"
    local result="$2"
    if [ "$result" -eq 0 ]; then
        echo "PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $desc"
        FAIL=$((FAIL + 1))
    fi
}

# Test 1: Required Output section exists
grep -q '^## Required Output' "$CODER_ROLE"
check "Required Output section exists" $?

# Test 2: CODER_SUMMARY.md skeleton is in the role file
grep -q 'CODER_SUMMARY.md' "$CODER_ROLE"
check "CODER_SUMMARY.md mentioned in Required Output" $?

# Test 3: Status: IN PROGRESS in skeleton
grep -q '## Status: IN PROGRESS' "$CODER_ROLE"
check "Status: IN PROGRESS in skeleton" $?

# Test 4: What Was Implemented section in skeleton
grep -q '## What Was Implemented' "$CODER_ROLE"
check "What Was Implemented section in skeleton" $?

# Test 5: Root Cause section in skeleton
grep -q '## Root Cause (bugs only)' "$CODER_ROLE"
check "Root Cause (bugs only) section in skeleton" $?

# Test 6: Files Modified section in skeleton
grep -q '## Files Modified' "$CODER_ROLE"
check "Files Modified section in skeleton" $?

# Test 7: Human Notes Status section in skeleton
grep -q '## Human Notes Status' "$CODER_ROLE"
check "Human Notes Status section in skeleton" $?

# Test 8: fill in as you go placeholder for What Was Implemented
grep -A2 '## What Was Implemented' "$CODER_ROLE" | grep -q 'fill in as you go'
check "What Was Implemented has 'fill in as you go' placeholder" $?

# Test 9: fill in after diagnosis placeholder for Root Cause
grep -A2 '## Root Cause (bugs only)' "$CODER_ROLE" | grep -q 'fill in after diagnosis'
check "Root Cause has 'fill in after diagnosis' placeholder" $?

# Test 10: fill in as you go placeholder for Files Modified
grep -A2 '## Files Modified' "$CODER_ROLE" | grep -q 'fill in as you go'
check "Files Modified has 'fill in as you go' placeholder" $?

# Test 11: Status field documentation mentions COMPLETE or IN PROGRESS
grep -q 'COMPLETE\|IN PROGRESS' "$CODER_ROLE"
check "Status field documentation mentions COMPLETE or IN PROGRESS" $?

echo
echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" -eq 0 ]
