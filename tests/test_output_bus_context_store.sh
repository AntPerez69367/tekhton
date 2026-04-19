#!/usr/bin/env bash
# =============================================================================
# test_output_bus_context_store.sh — M99 — verify Output Bus context store
#
# Tests: out_init, out_set_context, out_ctx
# Coverage gaps from REVIEWER_REPORT: out_ctx on missing keys must not trigger
# set -u unbound-variable errors.
# =============================================================================
set -euo pipefail

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

PASS=0; FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1 — $2"; FAIL=$((FAIL+1)); }

# Stub dependencies that output.sh relies on (defined in common.sh before source)
_tui_strip_ansi() { printf '%s' "$*"; }
_tui_notify()     { :; }
_TUI_ACTIVE=false
CYAN="" RED="" GREEN="" YELLOW="" BOLD="" NC=""

# shellcheck source=../lib/output.sh
source "${TEKHTON_HOME}/lib/output.sh"

# =============================================================================
echo "=== Test 1: out_ctx on unknown key returns empty string (no set -u error) ==="

result=$(out_ctx totally_nonexistent_key 2>&1)
exit_code=0
out_ctx totally_nonexistent_key >/dev/null 2>&1 || exit_code=$?

if [[ "$exit_code" -eq 0 ]]; then
    pass "out_ctx missing_key exits 0"
else
    fail "out_ctx missing_key exit code" "expected 0, got $exit_code"
fi

if [[ -z "$result" ]]; then
    pass "out_ctx missing_key returns empty string"
else
    fail "out_ctx missing_key value" "expected empty, got '$result'"
fi

# =============================================================================
echo "=== Test 2: out_init sets all keys to defined (non-unbound) values ==="

out_init

# Every key listed in the milestone spec must be reachable without set -u error
for key in mode attempt max_attempts task milestone milestone_title \
            stage_order cli_flags current_stage current_model action_items; do
    val=$(out_ctx "$key" 2>&1)
    rc=0
    out_ctx "$key" >/dev/null 2>&1 || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        pass "out_init: out_ctx $key exits cleanly"
    else
        fail "out_init: out_ctx $key" "set -u triggered (exit $rc)"
    fi
done

# =============================================================================
echo "=== Test 3: out_init seeds attempt=1, max_attempts=1 ==="

out_init
attempt_val=$(out_ctx attempt)
if [[ "$attempt_val" == "1" ]]; then
    pass "out_init sets attempt=1"
else
    fail "out_init attempt default" "expected 1, got '$attempt_val'"
fi

max_val=$(out_ctx max_attempts)
if [[ "$max_val" == "1" ]]; then
    pass "out_init sets max_attempts=1"
else
    fail "out_init max_attempts default" "expected 1, got '$max_val'"
fi

# =============================================================================
echo "=== Test 4: out_set_context / out_ctx round-trip ==="

out_set_context mode "fix-nb"
got=$(out_ctx mode)
if [[ "$got" == "fix-nb" ]]; then
    pass "out_set_context mode=fix-nb, out_ctx mode returns fix-nb"
else
    fail "out_ctx mode" "expected fix-nb, got '$got'"
fi

out_set_context task "Add OAuth2 login"
got=$(out_ctx task)
if [[ "$got" == "Add OAuth2 login" ]]; then
    pass "out_set_context task, out_ctx returns same string"
else
    fail "out_ctx task" "expected 'Add OAuth2 login', got '$got'"
fi

# =============================================================================
echo "=== Test 5: out_set_context overwrites existing value ==="

out_set_context attempt "3"
out_set_context attempt "7"
got=$(out_ctx attempt)
if [[ "$got" == "7" ]]; then
    pass "second out_set_context overwrites first"
else
    fail "out_set_context overwrite" "expected 7, got '$got'"
fi

# =============================================================================
echo "=== Test 6: out_set_context with empty key is a no-op (no error) ==="

rc=0
out_set_context "" "should-be-ignored" 2>/dev/null || rc=$?
if [[ "$rc" -eq 0 ]]; then
    pass "out_set_context empty key returns 0"
else
    fail "out_set_context empty key" "expected exit 0, got $rc"
fi

# =============================================================================
echo "=== Test 7: multiple independent keys coexist ==="

out_set_context milestone "99"
out_set_context milestone_title "Output Bus Core"
out_set_context current_stage "coder"

m=$(out_ctx milestone)
mt=$(out_ctx milestone_title)
cs=$(out_ctx current_stage)

if [[ "$m" == "99" ]] && [[ "$mt" == "Output Bus Core" ]] && [[ "$cs" == "coder" ]]; then
    pass "three keys coexist independently"
else
    fail "multiple keys" "milestone='$m' milestone_title='$mt' current_stage='$cs'"
fi

# =============================================================================
echo "=== Test 8: out_ctx with empty key arg returns empty string (no error) ==="

rc=0
result=$(out_ctx "" 2>&1) || rc=$?
if [[ "$rc" -eq 0 ]]; then
    pass "out_ctx empty key exits 0"
else
    fail "out_ctx empty key" "expected exit 0, got $rc"
fi
if [[ -z "$result" ]]; then
    pass "out_ctx empty key returns empty string"
else
    fail "out_ctx empty key value" "expected empty, got '$result'"
fi

echo ""
echo "=== Summary: ${PASS} passed, ${FAIL} failed ==="
[[ "$FAIL" -eq 0 ]]
