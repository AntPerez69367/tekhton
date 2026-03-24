#!/usr/bin/env bash
set -euo pipefail
# =============================================================================
# test_test_baseline.sh — Tests for lib/test_baseline.sh
#
# Tests: _normalize_test_output, _extract_failure_lines, capture_test_baseline,
#        has_test_baseline, compare_test_with_baseline, _check_acceptance_stuck,
#        save_acceptance_test_output, get_acceptance_output_hash
# =============================================================================

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export TEKHTON_HOME

# --- Test harness (same pattern as other tests) ---
_PASS=0 _FAIL=0
pass() { _PASS=$((_PASS + 1)); echo "PASS: $1"; }
fail() { _FAIL=$((_FAIL + 1)); echo "FAIL: $1"; if [[ "${2:-}" == "fatal" ]]; then exit 1; fi; }

# --- Setup: source minimal dependencies ---
# Stub common.sh functions
log() { :; }
warn() { :; }
success() { :; }
header() { :; }
export -f log warn success header

# Source the module under test
source "${TEKHTON_HOME}/lib/test_baseline.sh"

# --- Test temp dir ---
TEST_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_TMP"' EXIT

# =============================================================================
# Suite 1: _normalize_test_output
# =============================================================================

echo ""
echo "=== Suite 1: _normalize_test_output ==="

# 1.1: Strips ANSI color codes
input=$'\033[0;32mPASS\033[0m test_foo.sh'
output=$(printf '%s' "$input" | _normalize_test_output)
if [[ "$output" = "PASS test_foo.sh" ]]; then
    pass "1.1: Strips ANSI color codes"
else
    fail "1.1: Expected 'PASS test_foo.sh', got '$output'"
fi

# 1.2: Replaces ISO timestamps
input='[2026-03-24T01:06:32Z] Test started'
output=$(printf '%s' "$input" | _normalize_test_output)
if echo "$output" | grep -q "TIMESTAMP"; then
    pass "1.2: Replaces ISO timestamps"
else
    fail "1.2: Timestamp not replaced in '$output'"
fi

# 1.3: Replaces duration measurements
input='Ran 42 tests in 3.2s'
output=$(printf '%s' "$input" | _normalize_test_output)
if echo "$output" | grep -q "N.NNs"; then
    pass "1.3: Replaces duration measurements"
else
    fail "1.3: Duration not replaced in '$output'"
fi

# 1.4: Replaces milliseconds
input='Completed in 450ms'
output=$(printf '%s' "$input" | _normalize_test_output)
if echo "$output" | grep -q "Nms"; then
    pass "1.4: Replaces milliseconds"
else
    fail "1.4: Milliseconds not replaced in '$output'"
fi

# 1.5: Preserves test names and file paths
input='FAIL tests/test_foo.sh (assertion failed)'
output=$(printf '%s' "$input" | _normalize_test_output)
if [[ "$output" = "$input" ]]; then
    pass "1.5: Preserves test names and file paths"
else
    fail "1.5: Test name mangled: '$output'"
fi

# =============================================================================
# Suite 2: _extract_failure_lines
# =============================================================================

echo ""
echo "=== Suite 2: _extract_failure_lines ==="

# 2.1: Extracts FAIL lines (bash test format)
output=$(printf 'PASS test_a.sh\nFAIL test_b.sh\nPASS test_c.sh\n' | _extract_failure_lines)
if echo "$output" | grep -q "FAIL test_b.sh"; then
    pass "2.1: Extracts FAIL lines"
else
    fail "2.1: FAIL line not extracted"
fi

# 2.2: Extracts Go test format
output=$(printf 'ok  pkg/foo\n--- FAIL: TestBar (0.01s)\n' | _extract_failure_lines)
if echo "$output" | grep -q "FAIL"; then
    pass "2.2: Extracts Go test format"
else
    fail "2.2: Go FAIL not extracted"
fi

# 2.3: Extracts ERROR: lines
output=$(printf 'Running...\nERROR: test_blah assertion failed\nDone\n' | _extract_failure_lines)
if echo "$output" | grep -q "ERROR:"; then
    pass "2.3: Extracts ERROR: lines"
else
    fail "2.3: ERROR: line not extracted"
fi

# 2.4: Returns empty for clean output
output=$(printf 'PASS test_a.sh\nPASS test_b.sh\nAll tests passed\n' | _extract_failure_lines)
if [[ -z "$output" ]]; then
    pass "2.4: Returns empty for clean output"
else
    fail "2.4: Expected empty, got '$output'"
fi

# =============================================================================
# Suite 3: capture_test_baseline
# =============================================================================

echo ""
echo "=== Suite 3: capture_test_baseline ==="

# 3.1: Creates JSON and output files when tests fail
export PROJECT_DIR="$TEST_TMP/proj1"
mkdir -p "$PROJECT_DIR/.claude"
export TEST_CMD="echo 'PASS a'; echo 'FAIL b'; exit 1"
export _CURRENT_MILESTONE="42"

capture_test_baseline "42" 2>/dev/null

if [[ -f "$PROJECT_DIR/.claude/TEST_BASELINE.json" ]]; then
    pass "3.1a: Creates TEST_BASELINE.json"
else
    fail "3.1a: TEST_BASELINE.json not created"
fi
if [[ -f "$PROJECT_DIR/.claude/TEST_BASELINE_OUTPUT.txt" ]]; then
    pass "3.1b: Creates TEST_BASELINE_OUTPUT.txt"
else
    fail "3.1b: TEST_BASELINE_OUTPUT.txt not created"
fi

# 3.2: Records non-zero exit code
exit_code=$(grep -oP '"exit_code"\s*:\s*\K[0-9]+' "$PROJECT_DIR/.claude/TEST_BASELINE.json" 2>/dev/null || echo "")
if [[ "$exit_code" = "1" ]]; then
    pass "3.2: Records non-zero exit code"
else
    fail "3.2: Expected exit_code 1, got '$exit_code'"
fi

# 3.3: Records failure count > 0
fc=$(grep -oP '"failure_count"\s*:\s*\K[0-9]+' "$PROJECT_DIR/.claude/TEST_BASELINE.json" 2>/dev/null || echo "0")
if [[ "$fc" -gt 0 ]]; then
    pass "3.3: Records failure count > 0"
else
    fail "3.3: Expected failure_count > 0, got '$fc'"
fi

# 3.4: Records zero exit code when tests pass
export PROJECT_DIR="$TEST_TMP/proj2"
mkdir -p "$PROJECT_DIR/.claude"
export TEST_CMD="echo 'PASS a'; echo 'PASS b'"
capture_test_baseline "42" 2>/dev/null
exit_code=$(grep -oP '"exit_code"\s*:\s*\K[0-9]+' "$PROJECT_DIR/.claude/TEST_BASELINE.json" 2>/dev/null || echo "")
if [[ "$exit_code" = "0" ]]; then
    pass "3.4: Records zero exit code when tests pass"
else
    fail "3.4: Expected exit_code 0, got '$exit_code'"
fi

# 3.5: Skips when TEST_CMD="true"
export PROJECT_DIR="$TEST_TMP/proj3"
mkdir -p "$PROJECT_DIR/.claude"
export TEST_CMD="true"
capture_test_baseline "42" 2>/dev/null
if [[ ! -f "$PROJECT_DIR/.claude/TEST_BASELINE.json" ]]; then
    pass "3.5: Skips when TEST_CMD=true"
else
    fail "3.5: Should not create baseline for TEST_CMD=true"
fi

# 3.6: Skips when TEST_CMD is empty
export PROJECT_DIR="$TEST_TMP/proj4"
mkdir -p "$PROJECT_DIR/.claude"
export TEST_CMD=""
capture_test_baseline "42" 2>/dev/null
if [[ ! -f "$PROJECT_DIR/.claude/TEST_BASELINE.json" ]]; then
    pass "3.6: Skips when TEST_CMD is empty"
else
    fail "3.6: Should not create baseline for empty TEST_CMD"
fi

# =============================================================================
# Suite 4: has_test_baseline
# =============================================================================

echo ""
echo "=== Suite 4: has_test_baseline ==="

# 4.1: Returns 0 when baseline exists for current milestone
export PROJECT_DIR="$TEST_TMP/proj1"
export _CURRENT_MILESTONE="42"
if has_test_baseline "42"; then
    pass "4.1: Returns 0 when baseline exists for current milestone"
else
    fail "4.1: Should return 0 for matching milestone"
fi

# 4.2: Returns 1 when no baseline file exists
export PROJECT_DIR="$TEST_TMP/proj_nonexistent"
if ! has_test_baseline "42"; then
    pass "4.2: Returns 1 when no baseline file exists"
else
    fail "4.2: Should return 1 when file missing"
fi

# 4.3: Returns 1 when baseline is for a different milestone
export PROJECT_DIR="$TEST_TMP/proj1"
if ! has_test_baseline "99"; then
    pass "4.3: Returns 1 when baseline is for a different milestone"
else
    fail "4.3: Should return 1 for mismatched milestone"
fi

# =============================================================================
# Suite 5: compare_test_with_baseline
# =============================================================================

echo ""
echo "=== Suite 5: compare_test_with_baseline ==="

# 5.1: Returns "pre_existing" when failure hash matches baseline
export PROJECT_DIR="$TEST_TMP/proj1"
export _CURRENT_MILESTONE="42"
# Reproduce the same output as the baseline capture
test_output=$(printf 'PASS a\nFAIL b\n')
result=$(compare_test_with_baseline "$test_output" "1")
if [[ "$result" = "pre_existing" ]]; then
    pass "5.1: Returns pre_existing when failure hash matches"
else
    fail "5.1: Expected pre_existing, got '$result'"
fi

# 5.2: Returns "new_failures" when baseline was clean
export PROJECT_DIR="$TEST_TMP/proj2"
export _CURRENT_MILESTONE="42"
test_output=$(printf 'PASS a\nFAIL b\n')
result=$(compare_test_with_baseline "$test_output" "1")
if [[ "$result" = "new_failures" ]]; then
    pass "5.2: Returns new_failures when baseline was clean"
else
    fail "5.2: Expected new_failures, got '$result'"
fi

# 5.3: Returns "new_failures" when failure count exceeds baseline
export PROJECT_DIR="$TEST_TMP/proj1"
export _CURRENT_MILESTONE="42"
test_output=$(printf 'FAIL b\nFAIL c\nFAIL d\n')
result=$(compare_test_with_baseline "$test_output" "1")
if [[ "$result" = "new_failures" ]]; then
    pass "5.3: Returns new_failures when count exceeds baseline"
else
    fail "5.3: Expected new_failures, got '$result'"
fi

# 5.4: Returns "inconclusive" when no baseline file exists
export PROJECT_DIR="$TEST_TMP/proj_nonexistent"
result=$(compare_test_with_baseline "FAIL x" "1")
if [[ "$result" = "inconclusive" ]]; then
    pass "5.4: Returns inconclusive when no baseline"
else
    fail "5.4: Expected inconclusive, got '$result'"
fi

# =============================================================================
# Suite 6: _check_acceptance_stuck
# =============================================================================

echo ""
echo "=== Suite 6: _check_acceptance_stuck ==="

# 6.1: Returns 1 (not stuck) on first call with no output
export PROJECT_DIR="$TEST_TMP/proj_stuck"
mkdir -p "$PROJECT_DIR/.claude"
_ORCH_LAST_ACCEPTANCE_HASH=""
_ORCH_IDENTICAL_ACCEPTANCE_COUNT=0
# No acceptance output file exists
local_result=0
_check_acceptance_stuck || local_result=$?
if [[ "$local_result" -eq 1 ]]; then
    pass "6.1: Returns 1 (not stuck) with no output"
else
    fail "6.1: Expected 1, got $local_result"
fi

# 6.2: Returns 1 (not stuck) with different hashes
_ORCH_LAST_ACCEPTANCE_HASH=""
_ORCH_IDENTICAL_ACCEPTANCE_COUNT=0
save_acceptance_test_output "FAIL test_a output_1" "1"
local_result=0
_check_acceptance_stuck || local_result=$?
if [[ "$local_result" -eq 1 ]]; then
    pass "6.2a: Returns 1 (not stuck) on first hash"
else
    fail "6.2a: Expected 1, got $local_result"
fi
# Different output
save_acceptance_test_output "FAIL test_b output_2" "1"
local_result=0
_check_acceptance_stuck || local_result=$?
if [[ "$local_result" -eq 1 ]]; then
    pass "6.2b: Returns 1 (not stuck) with different hash"
else
    fail "6.2b: Expected 1, got $local_result"
fi

# 6.3: Returns 2 (stuck, no auto-pass) after threshold identical hashes
export TEST_BASELINE_STUCK_THRESHOLD=2
export TEST_BASELINE_PASS_ON_STUCK=false
_ORCH_LAST_ACCEPTANCE_HASH=""
_ORCH_IDENTICAL_ACCEPTANCE_COUNT=0
save_acceptance_test_output "FAIL identical output" "1"
_check_acceptance_stuck || true  # first: sets hash, returns 1
save_acceptance_test_output "FAIL identical output" "1"
local_result=0
_check_acceptance_stuck || local_result=$?
if [[ "$local_result" -eq 2 ]]; then
    pass "6.3: Returns 2 (stuck, exit) after threshold"
else
    fail "6.3: Expected 2, got $local_result"
fi

# 6.4: Returns 0 (stuck, auto-pass) when PASS_ON_STUCK=true
export TEST_BASELINE_PASS_ON_STUCK=true
_ORCH_LAST_ACCEPTANCE_HASH=""
_ORCH_IDENTICAL_ACCEPTANCE_COUNT=0
save_acceptance_test_output "FAIL identical output again" "1"
_check_acceptance_stuck || true  # first
save_acceptance_test_output "FAIL identical output again" "1"
local_result=0
_check_acceptance_stuck || local_result=$?
if [[ "$local_result" -eq 0 ]]; then
    pass "6.4: Returns 0 (stuck, auto-pass) when PASS_ON_STUCK=true"
else
    fail "6.4: Expected 0, got $local_result"
fi

# 6.5: Respects custom threshold
export TEST_BASELINE_STUCK_THRESHOLD=3
export TEST_BASELINE_PASS_ON_STUCK=false
_ORCH_LAST_ACCEPTANCE_HASH=""
_ORCH_IDENTICAL_ACCEPTANCE_COUNT=0
save_acceptance_test_output "FAIL threshold test" "1"
_check_acceptance_stuck || true  # 1st
save_acceptance_test_output "FAIL threshold test" "1"
local_result=0
_check_acceptance_stuck || local_result=$?
if [[ "$local_result" -eq 1 ]]; then
    pass "6.5a: Returns 1 (not stuck) below custom threshold"
else
    fail "6.5a: Expected 1, got $local_result"
fi
save_acceptance_test_output "FAIL threshold test" "1"
local_result=0
_check_acceptance_stuck || local_result=$?
if [[ "$local_result" -eq 2 ]]; then
    pass "6.5b: Returns 2 (stuck) at custom threshold"
else
    fail "6.5b: Expected 2, got $local_result"
fi

# =============================================================================
# Suite 7: _should_capture_test_baseline
# =============================================================================

echo ""
echo "=== Suite 7: _should_capture_test_baseline ==="

# 7.1: Returns 0 (should capture) when no baseline exists
export PROJECT_DIR="$TEST_TMP/proj_fresh"
mkdir -p "$PROJECT_DIR/.claude"
export TEST_CMD="echo test"
export TEST_BASELINE_ENABLED=true
export _CURRENT_MILESTONE="99"
if _should_capture_test_baseline; then
    pass "7.1: Returns 0 when no baseline exists"
else
    fail "7.1: Should return 0 for fresh project"
fi

# 7.2: Returns 1 (skip) when baseline exists for current milestone
export PROJECT_DIR="$TEST_TMP/proj1"
export _CURRENT_MILESTONE="42"
export TEST_CMD="echo test"
export TEST_BASELINE_ENABLED=true
if ! _should_capture_test_baseline; then
    pass "7.2: Returns 1 when baseline exists"
else
    fail "7.2: Should return 1 when baseline exists"
fi

# 7.3: Returns 1 when TEST_CMD=true
export PROJECT_DIR="$TEST_TMP/proj_fresh"
export TEST_CMD="true"
export TEST_BASELINE_ENABLED=true
if ! _should_capture_test_baseline; then
    pass "7.3: Returns 1 when TEST_CMD=true"
else
    fail "7.3: Should return 1 for TEST_CMD=true"
fi

# 7.4: Returns 1 when disabled
export PROJECT_DIR="$TEST_TMP/proj_fresh"
export TEST_CMD="echo test"
export TEST_BASELINE_ENABLED=false
if ! _should_capture_test_baseline; then
    pass "7.4: Returns 1 when disabled"
else
    fail "7.4: Should return 1 when disabled"
fi

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "────────────────────────────────"
echo "  Passed: ${_PASS}  Failed: ${_FAIL}"
echo "────────────────────────────────"
[[ "$_FAIL" -eq 0 ]] || exit 1
