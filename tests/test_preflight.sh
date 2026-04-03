#!/usr/bin/env bash
set -euo pipefail
# =============================================================================
# test_preflight.sh — Unit tests for lib/preflight.sh
#
# Tests:
#   run_preflight_checks: enabled/disabled toggle, report generation
#   _preflight_check_dependencies: missing/stale node_modules detection
#   _preflight_check_tools: tool availability via mock, Playwright/Cypress cache
#   _preflight_check_env_vars: .env presence and key completeness
#   _preflight_check_runtime_version: version file matching
#   _preflight_check_lock_freshness: manifest vs lock mtime
#   _preflight_check_ports: port availability detection
#   PREFLIGHT_AUTO_FIX: reports but doesn't fix when false
#
# Milestone 55: Pre-flight Environment Validation
# =============================================================================

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export TEKHTON_HOME

# Source dependencies
# shellcheck source=/dev/null
source "${TEKHTON_HOME}/lib/common.sh"
# shellcheck source=/dev/null
source "${TEKHTON_HOME}/lib/detect.sh"
# shellcheck source=/dev/null
source "${TEKHTON_HOME}/lib/detect_test_frameworks.sh"
# shellcheck source=/dev/null
source "${TEKHTON_HOME}/lib/preflight.sh"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*"; FAIL=$((FAIL + 1)); }

# --- Test fixture setup -------------------------------------------------------

_make_test_dir() {
    local tmpdir
    tmpdir=$(mktemp -d)
    echo "$tmpdir"
}

_cleanup_test_dir() {
    [[ -n "${1:-}" ]] && rm -rf "$1"
}

# =============================================================================
# PREFLIGHT_ENABLED=false skips all checks
# =============================================================================

echo "=== PREFLIGHT_ENABLED=false ==="

export PREFLIGHT_ENABLED=false
PROJECT_DIR=$(_make_test_dir)
export PROJECT_DIR

run_preflight_checks
rc=$?
if [[ "$rc" -eq 0 ]]; then
    pass
else
    fail "PREFLIGHT_ENABLED=false should return 0, got $rc"
fi

# No report file should be created
if [[ ! -f "$PROJECT_DIR/PREFLIGHT_REPORT.md" ]]; then
    pass
else
    fail "Report should not be created when disabled"
fi

_cleanup_test_dir "$PROJECT_DIR"
export PREFLIGHT_ENABLED=true

# =============================================================================
# Missing node_modules detection
# =============================================================================

echo "=== Dependency check: missing node_modules ==="

PROJECT_DIR=$(_make_test_dir)
export PROJECT_DIR
export PREFLIGHT_AUTO_FIX=false

# Create lock file but no node_modules
echo '{}' > "$PROJECT_DIR/package-lock.json"

# Reset state and run check
_PF_PASS=0; _PF_WARN=0; _PF_FAIL=0; _PF_REMEDIATED=0; _PF_REPORT_LINES=()
_PF_LANGUAGES=""; _PF_TEST_FWS=""
_preflight_check_dependencies

if [[ "$_PF_FAIL" -ge 1 ]]; then
    pass
else
    fail "Missing node_modules should produce a fail (got fail=$_PF_FAIL)"
fi

_cleanup_test_dir "$PROJECT_DIR"

# =============================================================================
# Stale node_modules detection (lock newer than install marker)
# =============================================================================

echo "=== Dependency check: stale node_modules ==="

PROJECT_DIR=$(_make_test_dir)
export PROJECT_DIR
export PREFLIGHT_AUTO_FIX=false

mkdir -p "$PROJECT_DIR/node_modules"
# Create install marker first (older)
touch "$PROJECT_DIR/node_modules/.package-lock.json"
sleep 1
# Then lock file (newer)
echo '{}' > "$PROJECT_DIR/package-lock.json"

_PF_PASS=0; _PF_WARN=0; _PF_FAIL=0; _PF_REMEDIATED=0; _PF_REPORT_LINES=()
_PF_LANGUAGES=""; _PF_TEST_FWS=""
_preflight_check_dependencies

if [[ "$_PF_FAIL" -ge 1 ]]; then
    pass
else
    fail "Stale node_modules should produce a fail (got fail=$_PF_FAIL)"
fi

_cleanup_test_dir "$PROJECT_DIR"

# =============================================================================
# Up-to-date node_modules passes
# =============================================================================

echo "=== Dependency check: fresh node_modules ==="

PROJECT_DIR=$(_make_test_dir)

echo '{}' > "$PROJECT_DIR/package-lock.json"
mkdir -p "$PROJECT_DIR/node_modules"
# Install marker newer than lock
sleep 1
touch "$PROJECT_DIR/node_modules/.package-lock.json"

_PF_PASS=0; _PF_WARN=0; _PF_FAIL=0; _PF_REMEDIATED=0; _PF_REPORT_LINES=()
_PF_LANGUAGES=""; _PF_TEST_FWS=""
_preflight_check_dependencies

if [[ "$_PF_PASS" -ge 1 ]] && [[ "$_PF_FAIL" -eq 0 ]]; then
    pass
else
    fail "Fresh node_modules should pass (pass=$_PF_PASS, fail=$_PF_FAIL)"
fi

_cleanup_test_dir "$PROJECT_DIR"

# =============================================================================
# Environment variable check: missing .env
# =============================================================================

echo "=== Env vars: missing .env ==="

PROJECT_DIR=$(_make_test_dir)

printf 'DATABASE_URL=postgres://localhost\nSECRET_KEY=changeme\n' > "$PROJECT_DIR/.env.example"

_PF_PASS=0; _PF_WARN=0; _PF_FAIL=0; _PF_REMEDIATED=0; _PF_REPORT_LINES=()
_PF_LANGUAGES=""; _PF_TEST_FWS=""
_preflight_check_env_vars

if [[ "$_PF_WARN" -ge 1 ]]; then
    pass
else
    fail "Missing .env should produce a warning (warn=$_PF_WARN)"
fi

_cleanup_test_dir "$PROJECT_DIR"

# =============================================================================
# Environment variable check: missing keys in .env
# =============================================================================

echo "=== Env vars: missing keys ==="

PROJECT_DIR=$(_make_test_dir)

printf 'DATABASE_URL=postgres://localhost\nSECRET_KEY=changeme\n' > "$PROJECT_DIR/.env.example"
printf 'DATABASE_URL=postgres://localhost\n' > "$PROJECT_DIR/.env"

_PF_PASS=0; _PF_WARN=0; _PF_FAIL=0; _PF_REMEDIATED=0; _PF_REPORT_LINES=()
_PF_LANGUAGES=""; _PF_TEST_FWS=""
_preflight_check_env_vars

if [[ "$_PF_WARN" -ge 1 ]]; then
    pass
else
    fail "Missing key SECRET_KEY should produce a warning (warn=$_PF_WARN)"
fi

# Verify the report mentions the missing key
local_report=$(printf '%s\n' "${_PF_REPORT_LINES[@]}")
if echo "$local_report" | grep -q "SECRET_KEY"; then
    pass
else
    fail "Report should mention missing key SECRET_KEY"
fi

_cleanup_test_dir "$PROJECT_DIR"

# =============================================================================
# Environment variable check: all keys present
# =============================================================================

echo "=== Env vars: all keys present ==="

PROJECT_DIR=$(_make_test_dir)

printf 'DATABASE_URL=postgres://localhost\nSECRET_KEY=changeme\n' > "$PROJECT_DIR/.env.example"
printf 'DATABASE_URL=postgres://localhost\nSECRET_KEY=mykey\n' > "$PROJECT_DIR/.env"

_PF_PASS=0; _PF_WARN=0; _PF_FAIL=0; _PF_REMEDIATED=0; _PF_REPORT_LINES=()
_PF_LANGUAGES=""; _PF_TEST_FWS=""
_preflight_check_env_vars

if [[ "$_PF_PASS" -ge 1 ]] && [[ "$_PF_WARN" -eq 0 ]]; then
    pass
else
    fail "All keys present should pass (pass=$_PF_PASS, warn=$_PF_WARN)"
fi

_cleanup_test_dir "$PROJECT_DIR"

# =============================================================================
# Tool availability: pipeline config command check
# =============================================================================

echo "=== Tool check: pipeline config commands ==="

PROJECT_DIR=$(_make_test_dir)
export PROJECT_DIR
# These are read via ${!cmd_var:-} in preflight.sh
export ANALYZE_CMD="bash -c 'echo test'"
export BUILD_CHECK_CMD=""
export TEST_CMD="true"
export UI_TEST_CMD=""

_PF_PASS=0; _PF_WARN=0; _PF_FAIL=0; _PF_REMEDIATED=0; _PF_REPORT_LINES=()
_PF_LANGUAGES=""; _PF_TEST_FWS=""
_preflight_check_tools

# bash should be found (it's always available)
if [[ "$_PF_PASS" -ge 1 ]]; then
    pass
else
    fail "bash should be available (pass=$_PF_PASS)"
fi

# TEST_CMD=true should be skipped (no-op default)
if [[ "$_PF_WARN" -eq 0 ]]; then
    pass
else
    fail "TEST_CMD=true should be skipped, not warned (warn=$_PF_WARN)"
fi

_cleanup_test_dir "$PROJECT_DIR"
unset ANALYZE_CMD BUILD_CHECK_CMD TEST_CMD UI_TEST_CMD

# =============================================================================
# Lock freshness: package.json newer than lock file
# =============================================================================

echo "=== Lock freshness: stale lock ==="

PROJECT_DIR=$(_make_test_dir)

# Create lock file first (older)
echo '{}' > "$PROJECT_DIR/package-lock.json"
sleep 1
# Then manifest (newer)
echo '{"name":"test"}' > "$PROJECT_DIR/package.json"

_PF_PASS=0; _PF_WARN=0; _PF_FAIL=0; _PF_REMEDIATED=0; _PF_REPORT_LINES=()
_PF_LANGUAGES=""; _PF_TEST_FWS=""
_preflight_check_lock_freshness

if [[ "$_PF_WARN" -ge 1 ]]; then
    pass
else
    fail "Stale lock should produce a warning (warn=$_PF_WARN)"
fi

_cleanup_test_dir "$PROJECT_DIR"

# =============================================================================
# Lock freshness: lock newer than manifest (OK)
# =============================================================================

echo "=== Lock freshness: fresh lock ==="

PROJECT_DIR=$(_make_test_dir)

echo '{"name":"test"}' > "$PROJECT_DIR/package.json"
sleep 1
echo '{}' > "$PROJECT_DIR/package-lock.json"

_PF_PASS=0; _PF_WARN=0; _PF_FAIL=0; _PF_REMEDIATED=0; _PF_REPORT_LINES=()
_PF_LANGUAGES=""; _PF_TEST_FWS=""
_preflight_check_lock_freshness

if [[ "$_PF_PASS" -ge 1 ]] && [[ "$_PF_WARN" -eq 0 ]]; then
    pass
else
    fail "Fresh lock should pass (pass=$_PF_PASS, warn=$_PF_WARN)"
fi

_cleanup_test_dir "$PROJECT_DIR"

# =============================================================================
# Report generation format
# =============================================================================

echo "=== Report generation ==="

PROJECT_DIR=$(_make_test_dir)

# Set up a project with various markers
echo '{}' > "$PROJECT_DIR/package-lock.json"
mkdir -p "$PROJECT_DIR/node_modules"
touch "$PROJECT_DIR/node_modules/.package-lock.json"
printf 'DATABASE_URL=x\n' > "$PROJECT_DIR/.env.example"
printf 'DATABASE_URL=x\n' > "$PROJECT_DIR/.env"

export PREFLIGHT_AUTO_FIX=false
run_preflight_checks

if [[ -f "$PROJECT_DIR/PREFLIGHT_REPORT.md" ]]; then
    pass
else
    fail "PREFLIGHT_REPORT.md should be created"
fi

# Check report structure
if grep -q "^# Pre-flight Report" "$PROJECT_DIR/PREFLIGHT_REPORT.md"; then
    pass
else
    fail "Report should have title header"
fi

if grep -q "## Summary" "$PROJECT_DIR/PREFLIGHT_REPORT.md"; then
    pass
else
    fail "Report should have Summary section"
fi

if grep -q "## Checks" "$PROJECT_DIR/PREFLIGHT_REPORT.md"; then
    pass
else
    fail "Report should have Checks section"
fi

_cleanup_test_dir "$PROJECT_DIR"

# =============================================================================
# PREFLIGHT_AUTO_FIX=false reports but doesn't fix
# =============================================================================

echo "=== PREFLIGHT_AUTO_FIX=false ==="

PROJECT_DIR=$(_make_test_dir)
export PROJECT_DIR
export PREFLIGHT_AUTO_FIX=false

# Missing node_modules — normally would try to fix
echo '{}' > "$PROJECT_DIR/package-lock.json"

_PF_PASS=0; _PF_WARN=0; _PF_FAIL=0; _PF_REMEDIATED=0; _PF_REPORT_LINES=()
_PF_LANGUAGES=""; _PF_TEST_FWS=""
_preflight_check_dependencies

# Should fail, not fix
if [[ "$_PF_REMEDIATED" -eq 0 ]]; then
    pass
else
    fail "Auto-fix disabled should not remediate (remediated=$_PF_REMEDIATED)"
fi

if [[ "$_PF_FAIL" -ge 1 ]]; then
    pass
else
    fail "Should report fail when auto-fix disabled (fail=$_PF_FAIL)"
fi

_cleanup_test_dir "$PROJECT_DIR"
export PREFLIGHT_AUTO_FIX=true

# =============================================================================
# No applicable checks produces no report
# =============================================================================

echo "=== No applicable checks ==="

PROJECT_DIR=$(_make_test_dir)
# Empty project — no markers

run_preflight_checks
rc=$?

if [[ "$rc" -eq 0 ]]; then
    pass
else
    fail "Empty project should return 0 (got $rc)"
fi

if [[ ! -f "$PROJECT_DIR/PREFLIGHT_REPORT.md" ]]; then
    pass
else
    fail "No report should be created when no checks apply"
fi

_cleanup_test_dir "$PROJECT_DIR"

# =============================================================================
# PREFLIGHT_FAIL_ON_WARN=true treats warnings as failures
# =============================================================================

echo "=== PREFLIGHT_FAIL_ON_WARN=true ==="

PROJECT_DIR=$(_make_test_dir)
export PROJECT_DIR
export PREFLIGHT_FAIL_ON_WARN=true
export PREFLIGHT_AUTO_FIX=false

# Create a scenario that only produces warnings (missing .env)
printf 'DATABASE_URL=x\n' > "$PROJECT_DIR/.env.example"
# Also need some passing check so we generate a report
echo '{}' > "$PROJECT_DIR/package.json"

rc=0
run_preflight_checks || rc=$?

if [[ "$rc" -ne 0 ]]; then
    pass
else
    fail "PREFLIGHT_FAIL_ON_WARN should cause failure on warnings (got rc=$rc)"
fi

_cleanup_test_dir "$PROJECT_DIR"
export PREFLIGHT_FAIL_ON_WARN=false
export PREFLIGHT_AUTO_FIX=true

# =============================================================================
# Runtime version check: Node.js match
# =============================================================================

echo "=== Runtime version: Node.js ==="

PROJECT_DIR=$(_make_test_dir)

if command -v node &>/dev/null; then
    node_major=$(node --version | tr -d 'v' | cut -d. -f1)
    echo "$node_major" > "$PROJECT_DIR/.node-version"

    _PF_PASS=0; _PF_WARN=0; _PF_FAIL=0; _PF_REMEDIATED=0; _PF_REPORT_LINES=()
    _PF_LANGUAGES=""; _PF_TEST_FWS=""
    _preflight_check_runtime_version

    if [[ "$_PF_PASS" -ge 1 ]]; then
        pass
    else
        fail "Matching node version should pass (pass=$_PF_PASS)"
    fi
else
    # Node not installed — skip
    pass
fi

_cleanup_test_dir "$PROJECT_DIR"

# =============================================================================
# Runtime version check: Node.js mismatch
# =============================================================================

echo "=== Runtime version: Node.js mismatch ==="

PROJECT_DIR=$(_make_test_dir)

if command -v node &>/dev/null; then
    echo "999" > "$PROJECT_DIR/.node-version"

    _PF_PASS=0; _PF_WARN=0; _PF_FAIL=0; _PF_REMEDIATED=0; _PF_REPORT_LINES=()
    _PF_LANGUAGES=""; _PF_TEST_FWS=""
    _preflight_check_runtime_version

    if [[ "$_PF_WARN" -ge 1 ]]; then
        pass
    else
        fail "Mismatched node version should warn (warn=$_PF_WARN)"
    fi
else
    pass
fi

_cleanup_test_dir "$PROJECT_DIR"

# =============================================================================
# Generated code: Prisma schema without client
# =============================================================================

echo "=== Generated code: Prisma ==="

PROJECT_DIR=$(_make_test_dir)
export PROJECT_DIR
export PREFLIGHT_AUTO_FIX=false

mkdir -p "$PROJECT_DIR/prisma"
echo 'model User { id Int @id }' > "$PROJECT_DIR/prisma/schema.prisma"
mkdir -p "$PROJECT_DIR/node_modules"

_PF_PASS=0; _PF_WARN=0; _PF_FAIL=0; _PF_REMEDIATED=0; _PF_REPORT_LINES=()
_PF_LANGUAGES=""; _PF_TEST_FWS=""
_preflight_check_generated_code

if [[ "$_PF_FAIL" -ge 1 ]]; then
    pass
else
    fail "Missing Prisma client should produce a fail (fail=$_PF_FAIL)"
fi

_cleanup_test_dir "$PROJECT_DIR"
export PREFLIGHT_AUTO_FIX=true

# =============================================================================
# Port check: smoke test (no port in use expected on random port)
# =============================================================================

echo "=== Port check: no server config ==="

PROJECT_DIR=$(_make_test_dir)
export PROJECT_DIR
export UI_TEST_CMD=""
export BUILD_CHECK_CMD=""

_PF_PASS=0; _PF_WARN=0; _PF_FAIL=0; _PF_REMEDIATED=0; _PF_REPORT_LINES=()
_PF_LANGUAGES=""; _PF_TEST_FWS=""
_preflight_check_ports

# No ports to check — should produce no results
if [[ "$_PF_PASS" -eq 0 ]] && [[ "$_PF_WARN" -eq 0 ]]; then
    pass
else
    fail "No server config should produce no port checks (pass=$_PF_PASS, warn=$_PF_WARN)"
fi

_cleanup_test_dir "$PROJECT_DIR"
unset UI_TEST_CMD BUILD_CHECK_CMD

# =============================================================================
# Port check: with dev server pattern
# =============================================================================

echo "=== Port check: next dev ==="

PROJECT_DIR=$(_make_test_dir)
export PROJECT_DIR
export UI_TEST_CMD="next dev"
export BUILD_CHECK_CMD=""

_PF_PASS=0; _PF_WARN=0; _PF_FAIL=0; _PF_REMEDIATED=0; _PF_REPORT_LINES=()
_PF_LANGUAGES=""; _PF_TEST_FWS=""
_preflight_check_ports

# Port 3000 — should be either pass or warn depending on system state
total=$(( _PF_PASS + _PF_WARN ))
if [[ "$total" -ge 1 ]]; then
    pass
else
    fail "next dev should check port 3000 (total checks=$total)"
fi

_cleanup_test_dir "$PROJECT_DIR"
unset UI_TEST_CMD BUILD_CHECK_CMD

# =============================================================================
# Full run_preflight_checks integration
# =============================================================================

echo "=== Full integration: mixed project ==="

PROJECT_DIR=$(_make_test_dir)
export PROJECT_DIR
export PREFLIGHT_AUTO_FIX=false

# Set up a project with some passing and some warning checks
echo '{"name":"test"}' > "$PROJECT_DIR/package.json"
echo '{}' > "$PROJECT_DIR/package-lock.json"
mkdir -p "$PROJECT_DIR/node_modules"
touch "$PROJECT_DIR/node_modules/.package-lock.json"
printf 'API_KEY=xxx\n' > "$PROJECT_DIR/.env.example"
# No .env — will warn

run_preflight_checks
rc=$?

# Should succeed (warnings don't fail by default)
if [[ "$rc" -eq 0 ]]; then
    pass
else
    fail "Mixed project with warnings should succeed (got rc=$rc)"
fi

# Report should exist
if [[ -f "$PROJECT_DIR/PREFLIGHT_REPORT.md" ]]; then
    pass
else
    fail "Report should be created for mixed project"
fi

_cleanup_test_dir "$PROJECT_DIR"
export PREFLIGHT_AUTO_FIX=true

# =============================================================================
# Results
# =============================================================================

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
exit 0
