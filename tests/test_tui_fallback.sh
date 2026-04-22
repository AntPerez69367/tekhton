#!/usr/bin/env bash
# =============================================================================
# test_tui_fallback.sh — M97 — verify TUI silently disables on missing deps.
#
# Covers acceptance criteria:
#   - `TUI_ENABLED=false` → activation returns false with reason
#   - Non-interactive TTY → activation returns false with reason
#   - Python venv absent → activation returns false with reason
#   - tui_* functions are no-ops when inactive (do not crash, do not spawn)
#   - _tui_json_build_status produces valid JSON that matches the schema
# =============================================================================
set -euo pipefail

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

export TEKHTON_HOME
export PROJECT_DIR="$TMPDIR"
export TEKHTON_SESSION_DIR="$TMPDIR/session"
mkdir -p "$TEKHTON_SESSION_DIR"

# Stub logging helpers since common.sh is heavyweight.
log()      { :; }
warn()     { :; }
error()    { :; }
success()  { :; }
header()   { :; }
log_verbose() { :; }

# shellcheck disable=SC1091
source "${TEKHTON_HOME}/lib/tui.sh"

PASS=0; FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1 — $2"; FAIL=$((FAIL+1)); }

echo "=== Test 1: TUI_ENABLED=false disables activation ==="
TUI_ENABLED=false
if ! _tui_should_activate; then
    if [[ "$_TUI_DISABLED_REASON" == *"TUI_ENABLED=false"* ]]; then
        pass "_tui_should_activate returns 1 with correct reason"
    else
        fail "reason mismatch" "got: $_TUI_DISABLED_REASON"
    fi
else
    fail "_tui_should_activate returned 0 when TUI_ENABLED=false" ""
fi

echo "=== Test 2: non-interactive TTY disables activation ==="
TUI_ENABLED=auto
if ! _tui_should_activate </dev/null; then
    pass "non-TTY disables TUI"
else
    fail "non-TTY should disable TUI" ""
fi

echo "=== Test 3: missing venv disables activation ==="
TUI_ENABLED=true
TUI_VENV_DIR="/definitely/does/not/exist/$(date +%s)"
if ! _tui_should_activate </dev/null; then
    pass "missing venv disables TUI"
else
    fail "missing venv should disable TUI" ""
fi

echo "=== Test 4: tui_start on disabled config is a no-op ==="
TUI_ENABLED=false
_TUI_ACTIVE=false
tui_start
if [[ "$_TUI_ACTIVE" == "false" ]]; then
    pass "tui_start left _TUI_ACTIVE=false when disabled"
else
    fail "tui_start activated when TUI_ENABLED=false" ""
fi
if [[ -z "$_TUI_PID" ]]; then
    pass "no sidecar PID recorded"
else
    fail "sidecar should not have been spawned" "pid=$_TUI_PID"
fi

echo "=== Test 5: update/append/complete are no-ops when inactive ==="
_TUI_ACTIVE=false
tui_update_stage 1 4 "Coder" "opus"
tui_update_agent 10 50 42
tui_append_event info "test event"
tui_finish_stage "Coder" "opus" "10/50" "42s" "PASS"
tui_complete "SUCCESS"
pass "all no-op functions returned without error"

echo "=== Test 6: JSON builder produces valid output ==="
_TUI_ACTIVE=true
_TUI_STATUS_FILE="$TMPDIR/status.json"
_TUI_STATUS_TMP="$TMPDIR/status.json.tmp"
_TUI_CURRENT_STAGE_LABEL="Coder"
_TUI_CURRENT_STAGE_NUM=1
_TUI_CURRENT_STAGE_TOTAL=4
_TUI_CURRENT_STAGE_MODEL="claude-opus-4-7"
_TUI_AGENT_TURNS_USED=12
_TUI_AGENT_TURNS_MAX=70
_TUI_AGENT_ELAPSED_SECS=123
_TUI_AGENT_STATUS="running"
_TUI_RECENT_EVENTS=("14:23:01|info|hello" "14:23:02|success|world")
_TUI_STAGES_COMPLETE=()
_TUI_COMPLETE=false
_TUI_VERDICT=""
_TUI_PIPELINE_START_TS=$(date +%s)
TASK="M97"
_CURRENT_MILESTONE="97"

_tui_write_status
if [[ ! -f "$_TUI_STATUS_FILE" ]]; then
    fail "status file not written" ""
elif python3 -c "import json,sys; json.load(open('$_TUI_STATUS_FILE'))" 2>/dev/null; then
    pass "status file is valid JSON"
else
    fail "status file is not valid JSON" "$(head -c 400 "$_TUI_STATUS_FILE")"
fi

# Inspect a few required fields
if python3 -c "
import json,sys
d = json.load(open('$_TUI_STATUS_FILE'))
need = ['version','run_id','milestone','stage_label','agent_turns_used','agent_turns_max','recent_events','stages_complete','complete']
missing = [k for k in need if k not in d]
sys.exit(1 if missing else 0)
" 2>/dev/null; then
    pass "status JSON contains all required fields"
else
    fail "status JSON missing required keys" ""
fi

# Verify event strings survived the round-trip and value types are correct
if python3 -c "
import json,sys
d = json.load(open('$_TUI_STATUS_FILE'))
assert d['milestone'] == '97'
assert d['stage_label'] == 'Coder'
assert d['agent_turns_used'] == 12
assert d['agent_turns_max'] == 70
assert isinstance(d['recent_events'], list) and len(d['recent_events']) == 2
assert d['recent_events'][0]['msg'] == 'hello'
assert d['recent_events'][1]['level'] == 'success'
assert d['complete'] is False
" 2>/dev/null; then
    pass "status JSON field types + values correct"
else
    fail "status JSON values incorrect" ""
fi

echo ""
echo "=== Summary: ${PASS} passed, ${FAIL} failed ==="
[[ "$FAIL" -eq 0 ]]
