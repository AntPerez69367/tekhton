#!/usr/bin/env bash
# Test: templates/coder.md Status field is properly documented
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

# Test 1: Skeleton shows Status: IN PROGRESS
grep -q '## Status: IN PROGRESS' "$CODER_ROLE"
check "Skeleton shows Status: IN PROGRESS example" $?

# Test 2: Required sections list documents Status field
grep -q '## Status.*COMPLETE.*IN PROGRESS' "$CODER_ROLE"
check "Required sections list documents Status values" $?

# Test 3: Final act mentions setting COMPLETE
grep -q 'set.*## Status.*to.*COMPLETE' "$CODER_ROLE"
check "Instructions mention setting Status to COMPLETE" $?

# Test 4: Conditional logic for IN PROGRESS is documented
grep -q 'leave.*IN PROGRESS.*if work remains' "$CODER_ROLE"
check "Instructions explain when to leave IN PROGRESS" $?

# Test 5: Role file warns against premature COMPLETE
grep -q 'Do NOT set COMPLETE if any planned work is unfinished' "$CODER_ROLE"
check "Role file explicitly forbids premature COMPLETE status" $?

# Test 6: Architecture Change Proposals section is documented
grep -q '## Architecture Change Proposals' "$CODER_ROLE"
check "Role file documents Architecture Change Proposals section" $?

# Test 7: Omit instruction for non-applicable sections
grep -q 'omit\|omitted' "$CODER_ROLE"
check "Role file explains when to omit sections" $?

# Test 8: Status field is listed as required in the bulleted section
grep -q '## Status.*either' "$CODER_ROLE"
check "Bulleted requirements list includes Status field" $?

# Test 9: Remaining Work section only when IN PROGRESS
grep -q 'anything unfinished.*only if IN PROGRESS' "$CODER_ROLE"
check "Remaining Work section documented as conditional" $?

# Test 10: File begins with coder's mandate before entering Required Output
head -30 "$CODER_ROLE" | grep -q 'Agent Role\|Your Mandate'
check "Role context precedes Required Output section" $?

echo
echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" -eq 0 ]
