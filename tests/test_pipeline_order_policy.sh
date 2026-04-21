#!/usr/bin/env bash
# =============================================================================
# test_pipeline_order_policy.sh — Unit tests for pipeline_order_policy.sh
#
# Tests the four policy/metrics/planning functions:
#   - get_stage_metrics_key
#   - get_stage_array_key
#   - get_stage_policy
#   - get_run_stage_plan
# =============================================================================
set -euo pipefail

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

export TEKHTON_HOME
export PROJECT_DIR="$TMPDIR"

# Stub logging functions
log()         { :; }
warn()        { echo "[WARN] $*" >&2; }
error()       { echo "[ERROR] $*" >&2; }
success()     { :; }
header()      { :; }
log_verbose() { :; }

# Source the module (also sources pipeline_order_policy via source call at end)
# shellcheck disable=SC1091
source "${TEKHTON_HOME}/lib/pipeline_order.sh"

PASS=0
FAIL=0

pass() {
    echo "  PASS: $1"
    PASS=$((PASS + 1))
}

fail() {
    echo "  FAIL: $1 — $2"
    FAIL=$((FAIL + 1))
}

# =============================================================================
echo "=== Testing get_stage_metrics_key ==="

# Test reviewer aliases
result=$(get_stage_metrics_key "reviewer")
[[ "$result" == "review" ]] && pass "reviewer → review" || fail "reviewer → review" "got '$result'"

result=$(get_stage_metrics_key "review")
[[ "$result" == "review" ]] && pass "review → review (idempotent)" || fail "review → review" "got '$result'"

# Test tester aliases
result=$(get_stage_metrics_key "test_verify")
[[ "$result" == "tester" ]] && pass "test_verify → tester" || fail "test_verify → tester" "got '$result'"

result=$(get_stage_metrics_key "tester")
[[ "$result" == "tester" ]] && pass "tester → tester (idempotent)" || fail "tester → tester" "got '$result'"

result=$(get_stage_metrics_key "test")
[[ "$result" == "tester" ]] && pass "test → tester" || fail "test → tester" "got '$result'"

# Test tester-write aliases
result=$(get_stage_metrics_key "test_write")
[[ "$result" == "tester-write" ]] && pass "test_write → tester-write" || fail "test_write → tester-write" "got '$result'"

result=$(get_stage_metrics_key "tester_write")
[[ "$result" == "tester-write" ]] && pass "tester_write → tester-write" || fail "tester_write → tester-write" "got '$result'"

result=$(get_stage_metrics_key "tester-write")
[[ "$result" == "tester-write" ]] && pass "tester-write → tester-write (idempotent)" || fail "tester-write → tester-write" "got '$result'"

# Test jr_coder aliases
result=$(get_stage_metrics_key "jr_coder")
[[ "$result" == "rework" ]] && pass "jr_coder → rework" || fail "jr_coder → rework" "got '$result'"

result=$(get_stage_metrics_key "rework")
[[ "$result" == "rework" ]] && pass "rework → rework (idempotent)" || fail "rework → rework" "got '$result'"

result=$(get_stage_metrics_key "jr-coder")
[[ "$result" == "rework" ]] && pass "jr-coder → rework" || fail "jr-coder → rework" "got '$result'"

# Test wrap_up aliases
result=$(get_stage_metrics_key "wrap_up")
[[ "$result" == "wrap-up" ]] && pass "wrap_up → wrap-up" || fail "wrap_up → wrap-up" "got '$result'"

result=$(get_stage_metrics_key "wrap-up")
[[ "$result" == "wrap-up" ]] && pass "wrap-up → wrap-up (idempotent)" || fail "wrap-up → wrap-up" "got '$result'"

# Test fallback for unknown stages
result=$(get_stage_metrics_key "coder")
[[ "$result" == "coder" ]] && pass "coder → coder (fallback)" || fail "coder → coder" "got '$result'"

result=$(get_stage_metrics_key "security")
[[ "$result" == "security" ]] && pass "security → security (fallback)" || fail "security → security" "got '$result'"

# Test empty input (produces empty output via fallback, which is correct)
result=$(get_stage_metrics_key "")
# Empty input should go through get_stage_display_label fallback and return empty
[[ "$result" == "" ]] && pass "empty input handled" || fail "empty input" "got '$result'"

# =============================================================================
echo "=== Testing get_stage_array_key ==="

# Test the special cases
result=$(get_stage_array_key "review")
[[ "$result" == "reviewer" ]] && pass "review → reviewer" || fail "review → reviewer" "got '$result'"

result=$(get_stage_array_key "test_verify")
[[ "$result" == "tester" ]] && pass "test_verify → tester" || fail "test_verify → tester" "got '$result'"

result=$(get_stage_array_key "test_write")
[[ "$result" == "tester_write" ]] && pass "test_write → tester_write" || fail "test_write → tester_write" "got '$result'"

# Test fallback (pass-through)
result=$(get_stage_array_key "coder")
[[ "$result" == "coder" ]] && pass "coder → coder (pass-through)" || fail "coder → coder" "got '$result'"

result=$(get_stage_array_key "security")
[[ "$result" == "security" ]] && pass "security → security (pass-through)" || fail "security → security" "got '$result'"

result=$(get_stage_array_key "unknown_stage")
[[ "$result" == "unknown_stage" ]] && pass "unknown_stage → unknown_stage (pass-through)" || fail "unknown_stage" "got '$result'"

# =============================================================================
echo "=== Testing get_stage_policy ==="

# Test policy format: class|pill|timings|active|parent
test_policy() {
    local stage=$1
    local expected_class=$2
    local expected_pill=$3
    local expected_timings=$4
    local expected_active=$5
    local expected_parent=$6

    local result
    result=$(get_stage_policy "$stage")

    # Parse the policy string (format: class|pill|timings|active|parent)
    local class pill timings active parent
    IFS='|' read -r class pill timings active parent <<<"$result"

    local pass_test=true
    [[ "$class" == "$expected_class" ]] || pass_test=false
    [[ "$pill" == "$expected_pill" ]] || pass_test=false
    [[ "$timings" == "$expected_timings" ]] || pass_test=false
    [[ "$active" == "$expected_active" ]] || pass_test=false
    [[ "$parent" == "$expected_parent" ]] || pass_test=false

    if $pass_test; then
        pass "$stage policy correct"
    else
        fail "$stage policy" "expected $expected_class|$expected_pill|$expected_timings|$expected_active|$expected_parent, got $result"
    fi
}

# Test each stage type
test_policy "preflight" "pre" "yes" "yes" "yes" "-"
test_policy "intake" "pre" "yes" "yes" "yes" "-"
test_policy "architect" "pre" "conditional" "yes" "yes" "-"
test_policy "architect-remediation" "sub" "no" "yes" "yes" "architect"
test_policy "scout" "sub" "no" "yes" "yes" "coder"
test_policy "coder" "pipeline" "yes" "yes" "yes" "-"
test_policy "security" "pipeline" "yes" "yes" "yes" "-"
test_policy "review" "pipeline" "yes" "yes" "yes" "-"
test_policy "docs" "pipeline" "yes" "yes" "yes" "-"
test_policy "tester" "pipeline" "yes" "yes" "yes" "-"
test_policy "tester-write" "pipeline" "yes" "yes" "yes" "-"
test_policy "rework" "sub" "no" "yes" "yes" "review"
test_policy "wrap-up" "post" "yes" "yes" "yes" "-"

# Test fallback (unknown stage)
test_policy "unknown_stage" "op" "no" "no" "yes" "-"

# Test that get_stage_policy works with internal names via get_stage_metrics_key
result=$(get_stage_policy "reviewer")
class=$(echo "$result" | cut -d'|' -f1)
[[ "$class" == "pipeline" ]] && pass "get_stage_policy('reviewer') resolves correctly" || fail "reviewer resolution" "got '$result'"

# =============================================================================
echo "=== Testing get_run_stage_plan ==="

# Test 1: Default configuration (all enabled)
export PREFLIGHT_ENABLED="true"
export INTAKE_AGENT_ENABLED="true"
export FORCE_AUDIT="false"
export DRIFT_OBSERVATION_COUNT="0"
export DRIFT_OBSERVATION_THRESHOLD="8"
export DRIFT_RUNS_SINCE_AUDIT="0"
export DRIFT_RUNS_SINCE_AUDIT_THRESHOLD="5"
export SECURITY_AGENT_ENABLED="true"
export SKIP_SECURITY="false"
export SKIP_DOCS="false"
export DOCS_AGENT_ENABLED="false"
export PIPELINE_ORDER="standard"

result=$(get_run_stage_plan)
# Expected: preflight intake coder security review tester wrap-up
if [[ "$result" == "preflight intake coder security review tester wrap-up" ]]; then
    pass "standard order with all enabled"
else
    fail "standard order" "got '$result'"
fi

# Test 2: Preflight disabled
export PREFLIGHT_ENABLED="false"
result=$(get_run_stage_plan)
if [[ "$result" == "intake coder security review tester wrap-up" ]]; then
    pass "preflight disabled"
else
    fail "preflight disabled" "got '$result'"
fi

# Test 3: Intake disabled
export PREFLIGHT_ENABLED="true"
export INTAKE_AGENT_ENABLED="false"
result=$(get_run_stage_plan)
if [[ "$result" == "preflight coder security review tester wrap-up" ]]; then
    pass "intake disabled"
else
    fail "intake disabled" "got '$result'"
fi

# Test 4: Security disabled
export INTAKE_AGENT_ENABLED="true"
export SECURITY_AGENT_ENABLED="false"
result=$(get_run_stage_plan)
if [[ "$result" == "preflight intake coder review tester wrap-up" ]]; then
    pass "security disabled"
else
    fail "security disabled" "got '$result'"
fi

# Test 5: Security with SKIP_SECURITY
export SECURITY_AGENT_ENABLED="true"
export SKIP_SECURITY="true"
result=$(get_run_stage_plan)
if [[ "$result" == "preflight intake coder review tester wrap-up" ]]; then
    pass "SKIP_SECURITY flag"
else
    fail "SKIP_SECURITY" "got '$result'"
fi

# Test 6: Docs enabled
export SKIP_SECURITY="false"
export DOCS_AGENT_ENABLED="true"
result=$(get_run_stage_plan)
if [[ "$result" == "preflight intake coder docs security review tester wrap-up" ]]; then
    pass "docs enabled"
else
    fail "docs enabled" "got '$result'"
fi

# Test 7: Docs disabled via SKIP_DOCS
export DOCS_AGENT_ENABLED="true"
export SKIP_DOCS="true"
result=$(get_run_stage_plan)
if [[ "$result" == "preflight intake coder security review tester wrap-up" ]]; then
    pass "SKIP_DOCS flag"
else
    fail "SKIP_DOCS" "got '$result'"
fi

# Test 8: Force audit
export SKIP_DOCS="false"
export FORCE_AUDIT="true"
result=$(get_run_stage_plan)
if [[ "$result" =~ architect ]]; then
    pass "FORCE_AUDIT includes architect"
else
    fail "FORCE_AUDIT" "got '$result'"
fi

# Test 9: Architect via drift observation threshold
export FORCE_AUDIT="false"
export DRIFT_OBSERVATION_COUNT="10"
export DRIFT_OBSERVATION_THRESHOLD="8"
result=$(get_run_stage_plan)
if [[ "$result" =~ architect ]]; then
    pass "drift observation threshold triggers architect"
else
    fail "drift observation threshold" "got '$result'"
fi

# Test 10: Architect via runs since audit threshold
export DRIFT_OBSERVATION_COUNT="0"
export DRIFT_RUNS_SINCE_AUDIT="6"
export DRIFT_RUNS_SINCE_AUDIT_THRESHOLD="5"
result=$(get_run_stage_plan)
if [[ "$result" =~ architect ]]; then
    pass "runs since audit threshold triggers architect"
else
    fail "runs since audit threshold" "got '$result'"
fi

# Test 11: test_first pipeline order
export FORCE_AUDIT="false"
export DRIFT_RUNS_SINCE_AUDIT="0"
export PIPELINE_ORDER="test_first"
result=$(get_run_stage_plan)
if [[ "$result" =~ "tester-write" ]]; then
    pass "test_first order includes tester-write"
else
    fail "test_first order" "got '$result'"
fi

# Test 12: wrap-up is always last
export PIPELINE_ORDER="standard"
result=$(get_run_stage_plan)
if [[ "$result" =~ "wrap-up"$ ]]; then
    pass "wrap-up is always last"
else
    fail "wrap-up last" "got '$result'"
fi

# =============================================================================
echo ""
echo "========================================"
echo "Test Results: PASS=$PASS  FAIL=$FAIL"
echo "========================================"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi

exit 0
