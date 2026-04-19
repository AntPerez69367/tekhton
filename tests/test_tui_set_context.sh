#!/usr/bin/env bash
# =============================================================================
# test_tui_set_context.sh — M98 — direct unit tests for tui_set_context and
# _tui_stage_order_json.
#
# Coverage gap identified in REVIEWER_REPORT.md:
#   "tui_set_context in lib/tui.sh and _tui_stage_order_json in lib/tui_helpers.sh
#    have no direct shell unit tests."
# =============================================================================
set -euo pipefail

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

export TEKHTON_HOME
export PROJECT_DIR="$TMPDIR"
export TEKHTON_SESSION_DIR="$TMPDIR/session"
mkdir -p "$TEKHTON_SESSION_DIR"

# Stub logging functions expected by tui.sh
log()         { :; }
warn()        { :; }
error()       { :; }
success()     { :; }
header()      { :; }
log_verbose() { :; }

# shellcheck disable=SC1091
source "${TEKHTON_HOME}/lib/tui.sh"

PASS=0; FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1 — $2"; FAIL=$((FAIL+1)); }

# JSON reader using python3 (same as other TUI tests)
_read_json() {
    local file="$1" key="$2"
    python3 -c "import json,sys; d=json.load(open('$file')); print(d.get('$key',''))" 2>/dev/null
}

# Helper: activate TUI in write-only mode (no sidecar) so _tui_json_build_status
# can write status files.
_activate_write_mode() {
    _TUI_ACTIVE=true
    _TUI_STATUS_FILE="$TMPDIR/status.json"
    _TUI_STATUS_TMP="$TMPDIR/status.json.tmp"
    _TUI_PIPELINE_START_TS=$(date +%s)
    _TUI_RECENT_EVENTS=()
    _TUI_STAGES_COMPLETE=()
    _TUI_CURRENT_STAGE_LABEL=""
    _TUI_CURRENT_STAGE_MODEL=""
    _TUI_CURRENT_STAGE_NUM=0
    _TUI_CURRENT_STAGE_TOTAL=0
    _TUI_AGENT_TURNS_USED=0
    _TUI_AGENT_TURNS_MAX=0
    _TUI_AGENT_ELAPSED_SECS=0
    _TUI_AGENT_STATUS="idle"
    _TUI_COMPLETE=false
    _TUI_VERDICT=""
    TASK="test-task"
    _CURRENT_MILESTONE=""
    _CURRENT_RUN_ID="run-test"
    # Reset context globals to known state
    _TUI_RUN_MODE="task"
    _TUI_CLI_FLAGS=""
    _TUI_STAGE_ORDER=()
}

# =============================================================================
echo "=== tui_set_context: no arguments — defaults apply ==="
tui_set_context

if [[ "$_TUI_RUN_MODE" == "task" ]]; then
    pass "tui_set_context() with no args: _TUI_RUN_MODE defaults to 'task'"
else
    fail "_TUI_RUN_MODE" "expected 'task', got '$_TUI_RUN_MODE'"
fi

if [[ "$_TUI_CLI_FLAGS" == "" ]]; then
    pass "tui_set_context() with no args: _TUI_CLI_FLAGS defaults to empty"
else
    fail "_TUI_CLI_FLAGS" "expected empty, got '$_TUI_CLI_FLAGS'"
fi

if [[ "${#_TUI_STAGE_ORDER[@]}" -eq 0 ]]; then
    pass "tui_set_context() with no args: _TUI_STAGE_ORDER is empty array"
else
    fail "_TUI_STAGE_ORDER length" "expected 0, got ${#_TUI_STAGE_ORDER[@]}"
fi

# =============================================================================
echo "=== tui_set_context: mode only — no flags, no stages ==="
tui_set_context "milestone"

if [[ "$_TUI_RUN_MODE" == "milestone" ]]; then
    pass "tui_set_context('milestone'): _TUI_RUN_MODE=milestone"
else
    fail "_TUI_RUN_MODE" "expected 'milestone', got '$_TUI_RUN_MODE'"
fi

if [[ "$_TUI_CLI_FLAGS" == "" ]]; then
    pass "tui_set_context('milestone'): _TUI_CLI_FLAGS still empty"
else
    fail "_TUI_CLI_FLAGS" "expected empty, got '$_TUI_CLI_FLAGS'"
fi

if [[ "${#_TUI_STAGE_ORDER[@]}" -eq 0 ]]; then
    pass "tui_set_context('milestone'): _TUI_STAGE_ORDER still empty"
else
    fail "_TUI_STAGE_ORDER length" "expected 0, got ${#_TUI_STAGE_ORDER[@]}"
fi

# =============================================================================
echo "=== tui_set_context: mode + flags, no stages ==="
tui_set_context "fix" "--no-commit"

if [[ "$_TUI_RUN_MODE" == "fix" ]]; then
    pass "tui_set_context('fix','--no-commit'): _TUI_RUN_MODE=fix"
else
    fail "_TUI_RUN_MODE" "expected 'fix', got '$_TUI_RUN_MODE'"
fi

if [[ "$_TUI_CLI_FLAGS" == "--no-commit" ]]; then
    pass "tui_set_context('fix','--no-commit'): _TUI_CLI_FLAGS=--no-commit"
else
    fail "_TUI_CLI_FLAGS" "expected '--no-commit', got '$_TUI_CLI_FLAGS'"
fi

if [[ "${#_TUI_STAGE_ORDER[@]}" -eq 0 ]]; then
    pass "tui_set_context with only 2 args: _TUI_STAGE_ORDER is empty"
else
    fail "_TUI_STAGE_ORDER length" "expected 0, got ${#_TUI_STAGE_ORDER[@]}"
fi

# =============================================================================
echo "=== tui_set_context: mode + flags + stage list ==="
tui_set_context "milestone" "--auto-advance --skip-security" intake scout coder security review tester

if [[ "$_TUI_RUN_MODE" == "milestone" ]]; then
    pass "_TUI_RUN_MODE=milestone"
else
    fail "_TUI_RUN_MODE" "expected 'milestone', got '$_TUI_RUN_MODE'"
fi

if [[ "$_TUI_CLI_FLAGS" == "--auto-advance --skip-security" ]]; then
    pass "_TUI_CLI_FLAGS set correctly"
else
    fail "_TUI_CLI_FLAGS" "expected '--auto-advance --skip-security', got '$_TUI_CLI_FLAGS'"
fi

if [[ "${#_TUI_STAGE_ORDER[@]}" -eq 6 ]]; then
    pass "_TUI_STAGE_ORDER has 6 entries"
else
    fail "_TUI_STAGE_ORDER length" "expected 6, got ${#_TUI_STAGE_ORDER[@]}"
fi

if [[ "${_TUI_STAGE_ORDER[0]}" == "intake" && "${_TUI_STAGE_ORDER[5]}" == "tester" ]]; then
    pass "_TUI_STAGE_ORDER[0]=intake and [5]=tester"
else
    fail "_TUI_STAGE_ORDER entries" "got [0]=${_TUI_STAGE_ORDER[0]:-} [5]=${_TUI_STAGE_ORDER[5]:-}"
fi

# =============================================================================
echo "=== _tui_stage_order_json: empty order ==="
_TUI_STAGE_ORDER=()
result=$(_tui_stage_order_json)
if [[ "$result" == "[]" ]]; then
    pass "_tui_stage_order_json with empty order produces []"
else
    fail "_tui_stage_order_json empty" "expected '[]', got '$result'"
fi

# =============================================================================
echo "=== _tui_stage_order_json: single stage ==="
_TUI_STAGE_ORDER=("intake")
result=$(_tui_stage_order_json)
if [[ "$result" == '["intake"]' ]]; then
    pass "_tui_stage_order_json with one stage produces [\"intake\"]"
else
    fail "_tui_stage_order_json single" "expected '[\"intake\"]', got '$result'"
fi

# =============================================================================
echo "=== _tui_stage_order_json: multiple stages ==="
_TUI_STAGE_ORDER=(intake scout coder security review tester)
result=$(_tui_stage_order_json)
expected='["intake","scout","coder","security","review","tester"]'
if [[ "$result" == "$expected" ]]; then
    pass "_tui_stage_order_json with 6 stages produces correct JSON array"
else
    fail "_tui_stage_order_json multiple" "expected '$expected', got '$result'"
fi

# Validate it's parseable JSON via python3
python3 -c "
import json, sys
parsed = json.loads('$result')
assert len(parsed) == 6, f'expected 6 elements, got {len(parsed)}'
assert parsed[0] == 'intake', f'first={parsed[0]}'
assert parsed[5] == 'tester', f'last={parsed[5]}'
" 2>/dev/null \
    && pass "_tui_stage_order_json output is valid JSON with correct elements" \
    || fail "_tui_stage_order_json JSON validity" "python3 parse failed"

# =============================================================================
echo "=== _tui_stage_order_json: special characters are escaped ==="
_TUI_STAGE_ORDER=('foo"bar' 'baz\qux')
result=$(_tui_stage_order_json)

# Write to temp file to avoid shell → Python quoting ambiguity when passing
# the JSON array string via -c (backslashes and embedded quotes get
# re-interpreted by the shell before Python sees them).
echo "$result" > "$TMPDIR/so_special.json"
python3 - "$TMPDIR/so_special.json" <<'PYEOF' 2>/dev/null \
    && pass "_tui_stage_order_json escapes double-quotes and backslashes" \
    || fail "_tui_stage_order_json escaping" "JSON decode failed or wrong values; raw output: $result"
import json, sys
with open(sys.argv[1]) as f:
    parsed = json.loads(f.read())
assert len(parsed) == 2, f"expected 2 elements, got {len(parsed)}"
assert parsed[0] == 'foo"bar', f"element 0: got {repr(parsed[0])}"
assert parsed[1] == 'baz\\qux', f"element 1: got {repr(parsed[1])}"
PYEOF

# =============================================================================
echo "=== tui_set_context flows into _tui_json_build_status ==="
_activate_write_mode
tui_set_context "complete" "--auto-advance" intake coder review tester

# Manually call _tui_write_status so the JSON file is produced
_tui_write_status

if [[ ! -f "$_TUI_STATUS_FILE" ]]; then
    fail "_tui_write_status after tui_set_context" "status file not written"
else
    rm_val=$(_read_json "$_TUI_STATUS_FILE" "run_mode")
    if [[ "$rm_val" == "complete" ]]; then
        pass "JSON run_mode=complete after tui_set_context"
    else
        fail "JSON run_mode" "expected 'complete', got '$rm_val'"
    fi

    cf_val=$(_read_json "$_TUI_STATUS_FILE" "cli_flags")
    if [[ "$cf_val" == "--auto-advance" ]]; then
        pass "JSON cli_flags=--auto-advance after tui_set_context"
    else
        fail "JSON cli_flags" "expected '--auto-advance', got '$cf_val'"
    fi

    python3 -c "
import json, sys
d = json.load(open('$_TUI_STATUS_FILE'))
so = d.get('stage_order', [])
assert len(so) == 4, f'expected 4 stages, got {len(so)}: {so}'
assert so[0] == 'intake', f'first={so[0]}'
assert so[3] == 'tester', f'last={so[3]}'
" 2>/dev/null \
        && pass "JSON stage_order has correct stages after tui_set_context" \
        || fail "JSON stage_order" "$(python3 -c "import json; d=json.load(open('$_TUI_STATUS_FILE')); print(d.get('stage_order'))" 2>/dev/null)"
fi

# =============================================================================
echo "=== _tui_stage_order_json: falls back to _OUT_CTX[stage_order] (M100) ==="
# When _TUI_STAGE_ORDER is empty but _OUT_CTX[stage_order] is populated,
# the JSON emitter must derive the array from the Output Bus string.
_TUI_STAGE_ORDER=()
declare -gA _OUT_CTX 2>/dev/null || true
_OUT_CTX[stage_order]="intake scout coder review tester"
result=$(_tui_stage_order_json)
expected='["intake","scout","coder","review","tester"]'
if [[ "$result" == "$expected" ]]; then
    pass "_tui_stage_order_json falls back to _OUT_CTX[stage_order] when _TUI_STAGE_ORDER is empty"
else
    fail "_tui_stage_order_json OUT_CTX fallback" "expected '$expected', got '$result'"
fi

# And _TUI_STAGE_ORDER still takes precedence when both are set.
_TUI_STAGE_ORDER=(scout coder tester)
_OUT_CTX[stage_order]="intake scout coder review tester"
result=$(_tui_stage_order_json)
expected='["scout","coder","tester"]'
if [[ "$result" == "$expected" ]]; then
    pass "_tui_stage_order_json prefers _TUI_STAGE_ORDER over _OUT_CTX[stage_order]"
else
    fail "_tui_stage_order_json precedence" "expected '$expected', got '$result'"
fi

# Empty OUT_CTX stage_order AND empty array → empty JSON array
_TUI_STAGE_ORDER=()
_OUT_CTX[stage_order]=""
result=$(_tui_stage_order_json)
if [[ "$result" == "[]" ]]; then
    pass "_tui_stage_order_json returns [] when both _TUI_STAGE_ORDER and _OUT_CTX[stage_order] are empty"
else
    fail "_tui_stage_order_json both empty" "expected '[]', got '$result'"
fi

# =============================================================================
echo ""
echo "=== Summary: ${PASS} passed, ${FAIL} failed ==="
[[ "$FAIL" -eq 0 ]]
