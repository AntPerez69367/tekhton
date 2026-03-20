#!/usr/bin/env bash
# =============================================================================
# test_agent_counter.sh — Verify TOTAL_AGENT_INVOCATIONS increments inside
#                         the actual run_agent() code path (M16 coverage gap)
#
# The reviewer noted that test_orchestrate.sh Suite 9 validates the arithmetic
# manually (bare shell arithmetic) but does not call the real run_agent().
# If someone removed the increment from agent.sh, Suite 9 would still pass.
# This test exercises the actual run_agent() function via a stub claude binary
# and verifies the counter fires correctly.
# =============================================================================
set -euo pipefail

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# --- Pipeline globals that agent.sh expects ----------------------------------
PROJECT_DIR="$TMPDIR"
TEKHTON_SESSION_DIR="$TMPDIR"
LOG_FILE="$TMPDIR/test.log"
TOTAL_TURNS=0
TOTAL_TIME=0
STAGE_SUMMARY=""
CODER_MAX_TURNS=10
AGENT_TIMEOUT=0          # disable outer timeout (no claude binary needed)
AGENT_ACTIVITY_TIMEOUT=0 # disable activity timeout
AGENT_NULL_RUN_THRESHOLD=2
AGENT_SKIP_PERMISSIONS=false
TEKHTON_TEST_MODE=1      # suppress spinner (checks /dev/tty)

export PROJECT_DIR TEKHTON_SESSION_DIR LOG_FILE TOTAL_TURNS TOTAL_TIME STAGE_SUMMARY
export CODER_MAX_TURNS AGENT_TIMEOUT AGENT_ACTIVITY_TIMEOUT AGENT_NULL_RUN_THRESHOLD
export AGENT_SKIP_PERMISSIONS TEKHTON_TEST_MODE

mkdir -p "$TMPDIR"
touch "$LOG_FILE"

# Stub `claude` on PATH so agent_monitor_platform.sh doesn't warn about
# missing binary (it does `command -v claude` at source time).
mkdir -p "$TMPDIR/bin"
cat > "$TMPDIR/bin/claude" << 'CLAUDE_STUB'
#!/usr/bin/env bash
# Minimal stub: exit 0 immediately (agent_retry loop will classify this as success)
exit 0
CLAUDE_STUB
chmod +x "$TMPDIR/bin/claude"
export PATH="$TMPDIR/bin:$PATH"

# --- Source common.sh FIRST (agent.sh depends on log/warn/error/success) -----
source "${TEKHTON_HOME}/lib/common.sh"

# --- Source agent.sh (which sources its 5 dependencies automatically) ---------
# agent.sh sources: agent_monitor_platform.sh, agent_monitor.sh,
#                   agent_monitor_helpers.sh, agent_retry.sh, agent_helpers.sh
source "${TEKHTON_HOME}/lib/agent.sh"

# --- Override _run_with_retry AFTER sourcing to bypass actual invocation ------
# This replaces the retry loop so run_agent() doesn't need a real claude binary.
# We still let run_agent() execute all its code up to and after the call site,
# including the TOTAL_AGENT_INVOCATIONS increment at line 88.
_run_with_retry() {
    # Set the output globals that run_agent() reads after this call returns
    _RWR_EXIT=0
    _RWR_TURNS=1
    _RWR_WAS_ACTIVITY_TIMEOUT=false
    LAST_AGENT_RETRY_COUNT=0
    AGENT_ERROR_CATEGORY=""
    AGENT_ERROR_SUBCATEGORY=""
    AGENT_ERROR_TRANSIENT=""
    AGENT_ERROR_MESSAGE=""
}

# Override _append_agent_summary to be a no-op (avoids writing to log file)
_append_agent_summary() { :; }

# count_lines is used inside run_agent for CODER_SUMMARY.md check
count_lines() { wc -l | tr -d '[:space:]'; }

# --- Test helpers ------------------------------------------------------------
PASS=0
FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc — expected '$expected', got '$actual'"
        FAIL=$((FAIL + 1))
    fi
}

# =============================================================================
# Test Suite 1: TOTAL_AGENT_INVOCATIONS increments via real run_agent()
# =============================================================================
echo "=== Test Suite 1: TOTAL_AGENT_INVOCATIONS via run_agent() ==="

# Reset counter
TOTAL_AGENT_INVOCATIONS=0

# First call
run_agent "TestAgent" "claude-sonnet-4-6" "5" "test prompt" "$LOG_FILE" \
    "Read Glob" > /dev/null 2>&1

assert_eq "1.1 counter increments to 1 after first run_agent call" \
    "1" "$TOTAL_AGENT_INVOCATIONS"

# Second call
run_agent "TestAgent2" "claude-sonnet-4-6" "5" "test prompt 2" "$LOG_FILE" \
    "Read Glob" > /dev/null 2>&1

assert_eq "1.2 counter increments to 2 after second run_agent call" \
    "2" "$TOTAL_AGENT_INVOCATIONS"

# Third call
run_agent "TestAgent3" "claude-sonnet-4-6" "5" "test prompt 3" "$LOG_FILE" \
    "Read Glob" > /dev/null 2>&1

assert_eq "1.3 counter increments to 3 after third run_agent call" \
    "3" "$TOTAL_AGENT_INVOCATIONS"

# =============================================================================
# Test Suite 2: Counter resets do not carry over — arithmetic is additive
# =============================================================================
echo "=== Test Suite 2: Counter accumulation ==="

TOTAL_AGENT_INVOCATIONS=10

run_agent "ResetTest" "claude-sonnet-4-6" "5" "test" "$LOG_FILE" \
    "Read" > /dev/null 2>&1

assert_eq "2.1 counter increments from existing value (10 → 11)" \
    "11" "$TOTAL_AGENT_INVOCATIONS"

# =============================================================================
# Test Suite 3: Counter is independent from TOTAL_TURNS
# =============================================================================
echo "=== Test Suite 3: TOTAL_AGENT_INVOCATIONS is distinct from TOTAL_TURNS ==="

TOTAL_AGENT_INVOCATIONS=0
TOTAL_TURNS=0

run_agent "TurnsTest" "claude-sonnet-4-6" "5" "test" "$LOG_FILE" \
    "Read" > /dev/null 2>&1

assert_eq "3.1 TOTAL_AGENT_INVOCATIONS = 1 (one call)" "1" "$TOTAL_AGENT_INVOCATIONS"
# TOTAL_TURNS accumulates turns_used from _RWR_TURNS (1 in our stub)
assert_eq "3.2 TOTAL_TURNS = 1 (one turn used by stub)" "1" "$TOTAL_TURNS"

# =============================================================================
# Summary
# =============================================================================
echo
echo "════════════════════════════════════════"
echo "  agent_counter tests: ${PASS} passed, ${FAIL} failed"
echo "════════════════════════════════════════"

[ "$FAIL" -eq 0 ] || exit 1
echo "All agent counter tests passed"
