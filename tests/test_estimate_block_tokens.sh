#!/usr/bin/env bash
# Test: lib/context_budget.sh — _estimate_block_tokens positional-parameter idiom
# Verifies the function works correctly after replacing local -n nameref with "$@"
set -euo pipefail

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS=0
FAIL=0

pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*"; FAIL=$((FAIL + 1)); }

# Source dependencies (context_compiler.sh sources context_budget.sh)
# shellcheck source=/dev/null
source "${TEKHTON_HOME}/lib/common.sh"
# shellcheck source=/dev/null
source "${TEKHTON_HOME}/lib/context.sh"
# shellcheck source=/dev/null
source "${TEKHTON_HOME}/lib/context_compiler.sh"

# =============================================================================
# _estimate_block_tokens — positional-parameter idiom
# =============================================================================

echo "=== _estimate_block_tokens ==="

# Single variable: 4 chars / 4 cpt = 1 token
CHARS_PER_TOKEN=4
export VAR_A="abcd"
result=$(_estimate_block_tokens "VAR_A")
if [[ "$result" -eq 1 ]]; then
    pass "single variable 4 chars → 1 token (CHARS_PER_TOKEN=4)"
else
    fail "single variable 4 chars: expected 1 token, got ${result}"
fi

# Single variable: 8 chars / 4 cpt = 2 tokens
export VAR_B="abcdefgh"
result=$(_estimate_block_tokens "VAR_B")
if [[ "$result" -eq 2 ]]; then
    pass "single variable 8 chars → 2 tokens"
else
    fail "single variable 8 chars: expected 2 tokens, got ${result}"
fi

# Multiple variables: summed char count
export VAR_C="abcd"   # 4 chars
export VAR_D="efgh"   # 4 chars
# total = 8 chars / 4 cpt = 2 tokens
result=$(_estimate_block_tokens "VAR_C" "VAR_D")
if [[ "$result" -eq 2 ]]; then
    pass "two variables summed: 8 chars → 2 tokens"
else
    fail "two variables summed: expected 2 tokens, got ${result}"
fi

# Three variables
export VAR_E="abcdefgh"   # 8 chars
export VAR_F="ijklmnop"   # 8 chars
export VAR_G="qrstuvwx"   # 8 chars
# total = 24 chars / 4 cpt = 6 tokens
result=$(_estimate_block_tokens "VAR_E" "VAR_F" "VAR_G")
if [[ "$result" -eq 6 ]]; then
    pass "three variables summed: 24 chars → 6 tokens"
else
    fail "three variables summed: expected 6 tokens, got ${result}"
fi

# Empty variable contributes 0 chars
export VAR_EMPTY=""
export VAR_NONEMPTY="abcd"  # 4 chars
result=$(_estimate_block_tokens "VAR_EMPTY" "VAR_NONEMPTY")
if [[ "$result" -eq 1 ]]; then
    pass "empty + 4-char variable → 1 token"
else
    fail "empty + 4-char: expected 1 token, got ${result}"
fi

# All empty variables → 0 tokens
export VAR_E1=""
export VAR_E2=""
result=$(_estimate_block_tokens "VAR_E1" "VAR_E2")
if [[ "$result" -eq 0 ]]; then
    pass "all-empty variables → 0 tokens"
else
    fail "all-empty variables: expected 0 tokens, got ${result}"
fi

# No arguments → 0 tokens
result=$(_estimate_block_tokens)
if [[ "$result" -eq 0 ]]; then
    pass "no arguments → 0 tokens"
else
    fail "no arguments: expected 0 tokens, got ${result}"
fi

# Ceiling division: 5 chars / 4 cpt → ceil(1.25) = 2 tokens
CHARS_PER_TOKEN=4
export VAR_ODD="abcde"  # 5 chars
result=$(_estimate_block_tokens "VAR_ODD")
if [[ "$result" -eq 2 ]]; then
    pass "5 chars with CHARS_PER_TOKEN=4 → ceiling division gives 2 tokens"
else
    fail "ceiling division: expected 2 tokens for 5 chars, got ${result}"
fi

# Custom CHARS_PER_TOKEN=1: chars == tokens
CHARS_PER_TOKEN=1
export VAR_CPT="abcdef"  # 6 chars
result=$(_estimate_block_tokens "VAR_CPT")
if [[ "$result" -eq 6 ]]; then
    pass "CHARS_PER_TOKEN=1: 6 chars → 6 tokens"
else
    fail "CHARS_PER_TOKEN=1: expected 6 tokens, got ${result}"
fi

# Custom CHARS_PER_TOKEN=2: 10 chars / 2 = 5 tokens
CHARS_PER_TOKEN=2
export VAR_CPT2="abcdefghij"  # 10 chars
result=$(_estimate_block_tokens "VAR_CPT2")
if [[ "$result" -eq 5 ]]; then
    pass "CHARS_PER_TOKEN=2: 10 chars → 5 tokens"
else
    fail "CHARS_PER_TOKEN=2: expected 5 tokens, got ${result}"
fi

# Default CHARS_PER_TOKEN (4) used when unset
unset CHARS_PER_TOKEN
export VAR_DEF="abcdefgh"  # 8 chars; default 4 → 2 tokens
result=$(_estimate_block_tokens "VAR_DEF")
if [[ "$result" -eq 2 ]]; then
    pass "default CHARS_PER_TOKEN=4: 8 chars → 2 tokens"
else
    fail "default CHARS_PER_TOKEN: expected 2 tokens for 8 chars, got ${result}"
fi

# Unset variable (not exported) treated as empty
unset UNSET_VAR 2>/dev/null || true
result=$(_estimate_block_tokens "UNSET_VAR")
if [[ "$result" -eq 0 ]]; then
    pass "unset variable treated as empty → 0 tokens"
else
    fail "unset variable: expected 0 tokens, got ${result}"
fi

# =============================================================================
# Summary
# =============================================================================

echo
echo "=== Summary ==="
echo "  Passed: ${PASS}  Failed: ${FAIL}"

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
