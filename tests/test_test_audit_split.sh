#!/usr/bin/env bash
# test_test_audit_split.sh — Verify M95 split of lib/test_audit.sh
#
# Sources each extracted companion module in isolation (plus common.sh) and
# asserts the expected functions are defined and callable with stub inputs.
set -euo pipefail

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

PROJECT_DIR="$TMPDIR_TEST"
export TEKHTON_HOME PROJECT_DIR

cd "$PROJECT_DIR"
git init -q
git commit --allow-empty -m "init" -q

PASS=0
FAIL=0

pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

echo "Test: M95 split — each extracted function callable from its new home"

# Each module is sourced in a subshell after common.sh so a failure in one
# doesn't poison the next.

# --- Parent under 300 lines --------------------------------------------------
parent_lines=$(wc -l < "${TEKHTON_HOME}/lib/test_audit.sh")
if [[ "$parent_lines" -le 300 ]]; then
    pass "lib/test_audit.sh is ${parent_lines} lines (≤ 300)"
else
    fail "lib/test_audit.sh is ${parent_lines} lines (> 300)"
fi

# --- test_audit_detection.sh -------------------------------------------------
if (
    set -euo pipefail
    source "${TEKHTON_HOME}/lib/common.sh"
    source "${TEKHTON_HOME}/lib/test_audit_detection.sh"
    declare -F _detect_orphaned_tests >/dev/null
    declare -F _detect_test_weakening >/dev/null
    # Callable with no input → empty findings, exit 0
    _AUDIT_TEST_FILES=""
    _AUDIT_DELETED_FILES=""
    _detect_orphaned_tests
    _detect_test_weakening
); then
    pass "test_audit_detection.sh: both detection functions defined and callable"
else
    fail "test_audit_detection.sh: sourcing or invocation failed"
fi

# --- test_audit_verdict.sh ---------------------------------------------------
if (
    set -euo pipefail
    source "${TEKHTON_HOME}/lib/common.sh"
    source "${TEKHTON_HOME}/lib/test_audit_verdict.sh"
    declare -F _parse_audit_verdict >/dev/null
    declare -F _route_audit_verdict >/dev/null
    TEST_AUDIT_REPORT_FILE=""
    verdict=$(_parse_audit_verdict)
    [[ "$verdict" == "PASS" ]]
    NON_BLOCKING_LOG_FILE="${PROJECT_DIR}/nb.md"
    _route_audit_verdict "PASS" >/dev/null
); then
    pass "test_audit_verdict.sh: both verdict functions defined and callable"
else
    fail "test_audit_verdict.sh: sourcing or invocation failed"
fi

# --- test_audit_helpers.sh ---------------------------------------------------
if (
    set -euo pipefail
    source "${TEKHTON_HOME}/lib/common.sh"
    source "${TEKHTON_HOME}/lib/test_audit_helpers.sh"
    declare -F _collect_audit_context >/dev/null
    declare -F _discover_all_test_files >/dev/null
    declare -F _build_test_audit_context >/dev/null
    TESTER_REPORT_FILE="${PROJECT_DIR}/missing_tester.md"
    CODER_SUMMARY_FILE="${PROJECT_DIR}/missing_coder.md"
    _collect_audit_context
    [[ -z "${_AUDIT_TEST_FILES:-}" ]]
    _build_test_audit_context
    [[ -n "${TEST_AUDIT_CONTEXT:-}" ]]
    _discover_all_test_files >/dev/null
); then
    pass "test_audit_helpers.sh: all helper functions defined and callable"
else
    fail "test_audit_helpers.sh: sourcing or invocation failed"
fi

# --- Parent orchestrator sources cleanly after companions --------------------
if (
    set -euo pipefail
    source "${TEKHTON_HOME}/lib/common.sh"
    source "${TEKHTON_HOME}/lib/test_audit_helpers.sh"
    source "${TEKHTON_HOME}/lib/test_audit_detection.sh"
    source "${TEKHTON_HOME}/lib/test_audit_verdict.sh"
    source "${TEKHTON_HOME}/lib/test_audit.sh"
    declare -F run_test_audit >/dev/null
    declare -F run_standalone_test_audit >/dev/null
); then
    pass "test_audit.sh: parent orchestrator loads and exports entry points"
else
    fail "test_audit.sh: parent orchestrator failed to load"
fi

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
