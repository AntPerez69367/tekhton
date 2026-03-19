#!/usr/bin/env bash
# =============================================================================
# test_auto_commit_conditional_default.sh — Conditional AUTO_COMMIT default
#
# Tests that AUTO_COMMIT defaults based on MILESTONE_MODE:
# - Defaults to true when MILESTONE_MODE=true
# - Defaults to false when MILESTONE_MODE=false or unset
# - User config in pipeline.conf overrides the conditional default
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
# Test 1: MILESTONE_MODE=false → AUTO_COMMIT defaults to false
# =============================================================================

MILESTONE_MODE=false
reload_defaults
assert_eq "1.1 MILESTONE_MODE=false → AUTO_COMMIT=false" "false" "$AUTO_COMMIT"

# =============================================================================
# Test 2: MILESTONE_MODE=true → AUTO_COMMIT defaults to true
# =============================================================================

MILESTONE_MODE=true
reload_defaults
assert_eq "2.1 MILESTONE_MODE=true → AUTO_COMMIT=true" "true" "$AUTO_COMMIT"

# =============================================================================
# Test 3: User-set AUTO_COMMIT=false overrides milestone mode default
# =============================================================================

# When user explicitly sets AUTO_COMMIT, the conditional should not override
AUTO_COMMIT=false  # User explicitly sets this
MILESTONE_MODE=true
source "${TEKHTON_HOME}/lib/config_defaults.sh"
assert_eq "3.1 user AUTO_COMMIT=false overrides milestone mode" "false" "$AUTO_COMMIT"

# =============================================================================
# Test 4: User-set AUTO_COMMIT=true in non-milestone mode is respected
# =============================================================================

AUTO_COMMIT=true  # User explicitly sets this
MILESTONE_MODE=false
source "${TEKHTON_HOME}/lib/config_defaults.sh"
assert_eq "4.1 user AUTO_COMMIT=true overrides non-milestone mode" "true" "$AUTO_COMMIT"

# =============================================================================
# Test 5: Unset AUTO_COMMIT in milestone mode defaults to true
# =============================================================================

unset AUTO_COMMIT 2>/dev/null || true
MILESTONE_MODE=true
reload_defaults
assert_eq "5.1 unset AUTO_COMMIT in milestone mode → true" "true" "$AUTO_COMMIT"

# =============================================================================
# Test 6: Unset AUTO_COMMIT in non-milestone mode defaults to false
# =============================================================================

unset AUTO_COMMIT 2>/dev/null || true
MILESTONE_MODE=false
reload_defaults
assert_eq "6.1 unset AUTO_COMMIT in non-milestone mode → false" "false" "$AUTO_COMMIT"

# =============================================================================
# Test 7: Unset MILESTONE_MODE defaults to false
# =============================================================================

unset MILESTONE_MODE 2>/dev/null || true
reload_defaults
assert_eq "7.1 unset MILESTONE_MODE → AUTO_COMMIT defaults to false" "false" "$AUTO_COMMIT"

# =============================================================================
# Test 8: MILESTONE_MODE set to empty string → defaults to false
# =============================================================================

MILESTONE_MODE=""
reload_defaults
assert_eq "8.1 MILESTONE_MODE='' → AUTO_COMMIT=false" "false" "$AUTO_COMMIT"

# =============================================================================
# Test 9: MILESTONE_MODE='true' (string) → AUTO_COMMIT=true
# =============================================================================

MILESTONE_MODE="true"
reload_defaults
assert_eq "9.1 MILESTONE_MODE='true' string → AUTO_COMMIT=true" "true" "$AUTO_COMMIT"

# =============================================================================

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
