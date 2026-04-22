#!/usr/bin/env bash
# =============================================================================
# test_tui_substage_json_clear.sh — M114 — end-to-end JSON clearing for
# tui_substage_end.
#
# Coverage gap from the M114 reviewer report: test_tui_substage_api.sh M113-3
# checks bash globals after tui_substage_end but never reads the status JSON
# file to confirm the clearing was flushed. This file exercises the full
# begin→end cycle at the bash level, verifying that after tui_substage_end the
# tui_status.json fields `current_substage_label` and `current_substage_start_ts`
# are cleared — which is what stops the renderer from showing the "coder » scout"
# breadcrumb.
# =============================================================================
set -euo pipefail

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

export TEKHTON_HOME
export PROJECT_DIR="$TMPDIR"
export TEKHTON_SESSION_DIR="$TMPDIR/session"
mkdir -p "$TEKHTON_SESSION_DIR"

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

_activate() {
    _TUI_ACTIVE=true
    _TUI_STATUS_FILE="$TMPDIR/status.json"
    _TUI_STATUS_TMP="$TMPDIR/status.json.tmp"
    _TUI_PIPELINE_START_TS=$(date +%s)
    _TUI_RECENT_EVENTS=()
    _TUI_STAGES_COMPLETE=()
    _TUI_STAGE_ORDER=()
    _TUI_CURRENT_STAGE_LABEL=""
    _TUI_CURRENT_STAGE_MODEL=""
    _TUI_CURRENT_STAGE_NUM=0
    _TUI_CURRENT_STAGE_TOTAL=0
    _TUI_AGENT_TURNS_USED=0
    _TUI_AGENT_TURNS_MAX=0
    _TUI_AGENT_ELAPSED_SECS=0
    _TUI_AGENT_STATUS="idle"
    _TUI_STAGE_START_TS=0
    _TUI_COMPLETE=false
    _TUI_VERDICT=""
    _TUI_STAGE_CYCLE=()
    _TUI_CURRENT_LIFECYCLE_ID=""
    _TUI_CLOSED_LIFECYCLE_IDS=()
    _TUI_CURRENT_SUBSTAGE_LABEL=""
    _TUI_CURRENT_SUBSTAGE_START_TS=0
    TUI_LIFECYCLE_V2=true
}

_json_field() {
    python3 -c "
import json, sys
d = json.load(open('$_TUI_STATUS_FILE'))
v = d.get('$1')
print('<MISSING>' if v is None else v)
" 2>/dev/null
}

# =============================================================================
echo "=== M114-json-1: tui_substage_end flushes empty label to JSON ==="
_activate
tui_stage_begin "coder" "claude-opus-4-7"
tui_substage_begin "scout" "claude-haiku-4-5"

pre_label=$(_json_field current_substage_label)
if [[ "$pre_label" == "scout" ]]; then
    pass "M114-json-1a: JSON shows 'scout' while substage is active"
else
    fail "M114-json-1a" "expected 'scout' before end, got '$pre_label'"
fi

tui_substage_end "scout" "PASS"

post_label=$(_json_field current_substage_label)
if [[ "$post_label" == "" ]]; then
    pass "M114-json-1b: JSON current_substage_label cleared to '' after end"
else
    fail "M114-json-1b" "expected '' after end, got '$post_label'"
fi

# =============================================================================
echo "=== M114-json-2: tui_substage_end flushes ts=0 to JSON ==="
_activate
tui_stage_begin "coder" "claude-opus-4-7"
tui_substage_begin "scout" "claude-haiku-4-5"

pre_ts=$(_json_field current_substage_start_ts)
if [[ "$pre_ts" != "0" && "$pre_ts" != "<MISSING>" ]]; then
    pass "M114-json-2a: JSON carries non-zero start_ts while substage active ($pre_ts)"
else
    fail "M114-json-2a" "expected non-zero ts before end, got '$pre_ts'"
fi

tui_substage_end "scout" "PASS"

post_ts=$(_json_field current_substage_start_ts)
if [[ "$post_ts" == "0" ]]; then
    pass "M114-json-2b: JSON current_substage_start_ts reset to 0 after end"
else
    fail "M114-json-2b" "expected '0' after end, got '$post_ts'"
fi

# =============================================================================
echo "=== M114-json-3: parent stage_label preserved in JSON after full cycle ==="
# Simulates the exact coder.sh pattern:
#   tui_substage_begin "scout"  (before run_agent Scout)
#   ... scout runs ...
#   tui_substage_end "scout" "PASS"  (after run_agent Scout)
_activate
tui_stage_begin "coder" "claude-opus-4-7"
tui_substage_begin "scout" "claude-haiku-4-5"
tui_substage_end "scout" "PASS"

parent_in_json=$(_json_field stage_label)
if [[ "$parent_in_json" == "coder" ]]; then
    pass "M114-json-3a: stage_label='coder' preserved in JSON after substage cycle"
else
    fail "M114-json-3a" "expected 'coder', got '$parent_in_json'"
fi

substage_in_json=$(_json_field current_substage_label)
if [[ "$substage_in_json" == "" ]]; then
    pass "M114-json-3b: current_substage_label='' in JSON (no breadcrumb) after cycle"
else
    fail "M114-json-3b" "expected '', got '$substage_in_json'"
fi

# =============================================================================
echo "=== M114-json-4: JSON state is correct at every phase of the cycle ==="
# Detailed sequence check that verifies the progression:
# idle → substage active → substage cleared
_activate
tui_stage_begin "coder" "claude-opus-4-7"

# Phase A: no substage yet
phase_a_label=$(_json_field current_substage_label)
phase_a_ts=$(_json_field current_substage_start_ts)
if [[ "$phase_a_label" == "" && "$phase_a_ts" == "0" ]]; then
    pass "M114-json-4a: before substage begin — label='', ts=0 in JSON"
else
    fail "M114-json-4a" "expected ''/'0', got '$phase_a_label'/'$phase_a_ts'"
fi

# Phase B: substage active
tui_substage_begin "scout" "claude-haiku-4-5"
phase_b_label=$(_json_field current_substage_label)
phase_b_ts=$(_json_field current_substage_start_ts)
if [[ "$phase_b_label" == "scout" && "$phase_b_ts" != "0" ]]; then
    pass "M114-json-4b: during substage — label='scout', ts>0 in JSON"
else
    fail "M114-json-4b" "expected 'scout'/non-zero, got '$phase_b_label'/'$phase_b_ts'"
fi

# Phase C: substage ended
tui_substage_end "scout" "PASS"
phase_c_label=$(_json_field current_substage_label)
phase_c_ts=$(_json_field current_substage_start_ts)
if [[ "$phase_c_label" == "" && "$phase_c_ts" == "0" ]]; then
    pass "M114-json-4c: after substage end — label='', ts=0 in JSON"
else
    fail "M114-json-4c" "expected ''/'0', got '$phase_c_label'/'$phase_c_ts'"
fi

tui_stage_end "coder" "claude-opus-4-7" "10/50" "30s" "PASS"

# =============================================================================
echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
