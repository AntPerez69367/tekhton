#!/usr/bin/env bash
# =============================================================================
# test_auto_commit_conditional_default.sh — AUTO_COMMIT default behavior
#
# Tests that AUTO_COMMIT defaults to true and respects explicit user overrides.
# =============================================================================
set -euo pipefail

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

PROJECT_DIR="$TMPDIR"
mkdir -p "$PROJECT_DIR/.claude"

FAIL=0

assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" != "$actual" ]; then
        echo "FAIL: $name — expected '$expected', got '$actual'"
        FAIL=1
    fi
}

cd "$PROJECT_DIR"

# Source dependencies once at the top
source "${TEKHTON_HOME}/lib/common.sh"
source "${TEKHTON_HOME}/lib/config.sh"

reload_defaults() {
    # Reload config_defaults.sh in a fresh subshell to ensure clean state
    unset AUTO_COMMIT 2>/dev/null || true
    source "${TEKHTON_HOME}/lib/config_defaults.sh"
}

# =============================================================================
# Test 1: AUTO_COMMIT defaults to true (regardless of MILESTONE_MODE)
# =============================================================================

MILESTONE_MODE=false
reload_defaults
assert_eq "1.1 AUTO_COMMIT defaults to true" "true" "$AUTO_COMMIT"

# =============================================================================
# Test 2: AUTO_COMMIT defaults to true in milestone mode too
# =============================================================================

MILESTONE_MODE=true
reload_defaults
assert_eq "2.1 MILESTONE_MODE=true → AUTO_COMMIT=true" "true" "$AUTO_COMMIT"

# =============================================================================
# Test 3: User-set AUTO_COMMIT=false overrides default
# =============================================================================

AUTO_COMMIT=false
MILESTONE_MODE=true
source "${TEKHTON_HOME}/lib/config_defaults.sh"
assert_eq "3.1 user AUTO_COMMIT=false overrides default" "false" "$AUTO_COMMIT"

# =============================================================================
# Test 4: User-set AUTO_COMMIT=true is respected
# =============================================================================

AUTO_COMMIT=true
MILESTONE_MODE=false
source "${TEKHTON_HOME}/lib/config_defaults.sh"
assert_eq "4.1 user AUTO_COMMIT=true is respected" "true" "$AUTO_COMMIT"

# =============================================================================
# Test 5: Unset AUTO_COMMIT in milestone mode defaults to true
# =============================================================================

unset AUTO_COMMIT 2>/dev/null || true
MILESTONE_MODE=true
reload_defaults
assert_eq "5.1 unset AUTO_COMMIT in milestone mode → true" "true" "$AUTO_COMMIT"

# =============================================================================
# Test 6: Unset AUTO_COMMIT in non-milestone mode defaults to true
# =============================================================================

unset AUTO_COMMIT 2>/dev/null || true
MILESTONE_MODE=false
reload_defaults
assert_eq "6.1 unset AUTO_COMMIT in non-milestone mode → true" "true" "$AUTO_COMMIT"

# =============================================================================
# Test 7: Unset MILESTONE_MODE → AUTO_COMMIT defaults to true
# =============================================================================

unset MILESTONE_MODE 2>/dev/null || true
reload_defaults
assert_eq "7.1 unset MILESTONE_MODE → AUTO_COMMIT defaults to true" "true" "$AUTO_COMMIT"

# =============================================================================
# Test 8: --no-commit override (AUTO_COMMIT=false) is respected
# =============================================================================

AUTO_COMMIT=false  # Simulates --no-commit flag
reload_defaults  # Should NOT override since AUTO_COMMIT is already set
# Note: reload_defaults unsets AUTO_COMMIT first, so we test differently
AUTO_COMMIT=false
source "${TEKHTON_HOME}/lib/config_defaults.sh"
assert_eq "8.1 --no-commit (AUTO_COMMIT=false) is respected" "false" "$AUTO_COMMIT"

# =============================================================================

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
