#!/usr/bin/env bash
# Test: templates/coder.md instructs creating CODER_SUMMARY.md BEFORE any code
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

# Test 1: "before writing any code" appears in Required Output section
grep -q 'before writing any code' "$CODER_ROLE"
check "Required Output contains 'before writing any code'" $?

# Test 2: It says to create the IN PROGRESS skeleton
grep -q 'IN PROGRESS skeleton' "$CODER_ROLE"
check "Required Output mentions IN PROGRESS skeleton" $?

# Test 3: It says to update throughout work
grep -q 'Update the file throughout your work' "$CODER_ROLE"
check "Required Output instructs updating throughout work" $?

# Test 4: It says to set Status to COMPLETE as final act
grep -q 'As your.*final act' "$CODER_ROLE"
check "Required Output mentions final act" $?

# Test 5: Final act sets Status to COMPLETE
grep -q 'set.*## Status.*to.*COMPLETE' "$CODER_ROLE"
check "Final act sets Status to COMPLETE" $?

# Test 6: The section explains Status can be IN PROGRESS or COMPLETE
grep -q '## Status.*COMPLETE\|IN PROGRESS' "$CODER_ROLE"
check "Role file documents Status field values" $?

# Test 7: The skeleton shows the status line
grep -q '## Status: IN PROGRESS' "$CODER_ROLE"
check "Skeleton contains Status: IN PROGRESS example" $?

# Test 8: The section contains instructions not to set COMPLETE if work is unfinished
grep -q 'Do NOT set COMPLETE if any planned work is unfinished' "$CODER_ROLE"
check "Role file warns against setting COMPLETE prematurely" $?

echo
echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" -eq 0 ]
