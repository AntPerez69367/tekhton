#!/usr/bin/env bash
# Test: coder.prompt.md has USER TASK delimiters and Scope Adherence section
set -euo pipefail

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROMPT_FILE="${TEKHTON_HOME}/prompts/coder.prompt.md"

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

# 1. BEGIN USER TASK delimiter present
grep -qF -- '--- BEGIN USER TASK' "$PROMPT_FILE"
check "BEGIN USER TASK delimiter present" $?

# 2. END USER TASK delimiter present
grep -qF -- '--- END USER TASK ---' "$PROMPT_FILE"
check "END USER TASK delimiter present" $?

# 3. {{TASK}} is between the delimiters
awk '/BEGIN USER TASK/,/END USER TASK/' "$PROMPT_FILE" | grep -q '{{TASK}}'
check "{{TASK}} is inside USER TASK delimiters" $?

# 4. Scope Adherence section heading present
grep -q '^## Scope Adherence' "$PROMPT_FILE"
check "Scope Adherence section heading present" $?

# 5. Scope Adherence section contains quantity language
grep -q 'quantity' "$PROMPT_FILE"
check "Scope Adherence section mentions quantity" $?

# 6. Scope Adherence section instructs not to expand scope
grep -q 'Do not expand scope' "$PROMPT_FILE"
check "Scope Adherence section contains 'Do not expand scope'" $?

echo
echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" -eq 0 ]
