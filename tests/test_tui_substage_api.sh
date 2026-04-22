#!/usr/bin/env bash
# =============================================================================
# test_tui_substage_api.sh — M113 — hierarchical substage API contract.
#
# Covers the new tui_substage_begin / tui_substage_end helpers introduced in
# M113 and the auto-close-and-warn rule baked into tui_stage_end. No caller
# is migrated in M113; this is a pure API contract test.
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
echo "=== M113-1: tui_substage_begin sets globals and writes status ==="
_activate
tui_stage_begin "coder" "claude-opus-4-7"
parent_label="$_TUI_CURRENT_STAGE_LABEL"
parent_start="$_TUI_STAGE_START_TS"
parent_id="$_TUI_CURRENT_LIFECYCLE_ID"

tui_substage_begin "scout" "claude-haiku-4-5"

if [[ "$_TUI_CURRENT_SUBSTAGE_LABEL" == "scout" ]]; then
    pass "M113-1a: _TUI_CURRENT_SUBSTAGE_LABEL=scout after begin"
else
    fail "M113-1a" "expected 'scout', got '$_TUI_CURRENT_SUBSTAGE_LABEL'"
fi
if (( _TUI_CURRENT_SUBSTAGE_START_TS > 0 )); then
    pass "M113-1b: _TUI_CURRENT_SUBSTAGE_START_TS populated"
else
    fail "M113-1b" "expected > 0, got '$_TUI_CURRENT_SUBSTAGE_START_TS'"
fi
got_label=$(_json_field current_substage_label)
if [[ "$got_label" == "scout" ]]; then
    pass "M113-1c: status JSON carries current_substage_label=scout"
else
    fail "M113-1c" "expected 'scout', got '$got_label'"
fi
got_ts=$(_json_field current_substage_start_ts)
if [[ "$got_ts" != "0" && "$got_ts" != "<MISSING>" ]]; then
    pass "M113-1d: status JSON carries current_substage_start_ts>0 ($got_ts)"
else
    fail "M113-1d" "expected non-zero int, got '$got_ts'"
fi

# =============================================================================
echo "=== M113-2: parent stage state untouched by substage begin ==="
if [[ "$_TUI_CURRENT_STAGE_LABEL" == "$parent_label" ]]; then
    pass "M113-2a: parent _TUI_CURRENT_STAGE_LABEL unchanged ($parent_label)"
else
    fail "M113-2a" "parent label changed: $parent_label → $_TUI_CURRENT_STAGE_LABEL"
fi
if [[ "$_TUI_STAGE_START_TS" == "$parent_start" ]]; then
    pass "M113-2b: parent _TUI_STAGE_START_TS unchanged"
else
    fail "M113-2b" "parent start_ts changed: $parent_start → $_TUI_STAGE_START_TS"
fi
if [[ "$_TUI_CURRENT_LIFECYCLE_ID" == "$parent_id" ]]; then
    pass "M113-2c: parent lifecycle id unchanged ($parent_id)"
else
    fail "M113-2c" "lifecycle id changed: $parent_id → $_TUI_CURRENT_LIFECYCLE_ID"
fi

# =============================================================================
echo "=== M113-3: tui_substage_end clears globals, no stages_complete row ==="
complete_before=${#_TUI_STAGES_COMPLETE[@]}
tui_substage_end "scout" "PASS"

if [[ "$_TUI_CURRENT_SUBSTAGE_LABEL" == "" ]]; then
    pass "M113-3a: _TUI_CURRENT_SUBSTAGE_LABEL cleared after end"
else
    fail "M113-3a" "expected '', got '$_TUI_CURRENT_SUBSTAGE_LABEL'"
fi
if [[ "$_TUI_CURRENT_SUBSTAGE_START_TS" == "0" ]]; then
    pass "M113-3b: _TUI_CURRENT_SUBSTAGE_START_TS reset to 0"
else
    fail "M113-3b" "expected 0, got '$_TUI_CURRENT_SUBSTAGE_START_TS'"
fi
complete_after=${#_TUI_STAGES_COMPLETE[@]}
if (( complete_after == complete_before )); then
    pass "M113-3c: substage end did NOT append to _TUI_STAGES_COMPLETE"
else
    fail "M113-3c" "_TUI_STAGES_COMPLETE grew: $complete_before → $complete_after"
fi

# =============================================================================
echo "=== M113-4: parent state still untouched after full begin/end cycle ==="
if [[ "$_TUI_CURRENT_STAGE_LABEL" == "$parent_label" \
   && "$_TUI_STAGE_START_TS" == "$parent_start" \
   && "$_TUI_CURRENT_LIFECYCLE_ID" == "$parent_id" ]]; then
    pass "M113-4: parent label/start_ts/lifecycle_id all preserved"
else
    fail "M113-4" "parent state mutated across substage cycle"
fi

# =============================================================================
echo "=== M113-5: auto-close + warn when parent ends with substage still open ==="
_activate
tui_stage_begin "review" "claude-opus-4-7"
tui_substage_begin "rework" "claude-opus-4-7"
# Parent ends while substage is still active.
tui_stage_end "review" "claude-opus-4-7" "12/50" "45s" "CHANGES_REQUIRED"

if [[ "$_TUI_CURRENT_SUBSTAGE_LABEL" == "" && "$_TUI_CURRENT_SUBSTAGE_START_TS" == "0" ]]; then
    pass "M113-5a: substage globals cleared by parent end"
else
    fail "M113-5a" "substage not auto-cleared (label='$_TUI_CURRENT_SUBSTAGE_LABEL', ts='$_TUI_CURRENT_SUBSTAGE_START_TS')"
fi

warn_count=0
for e in "${_TUI_RECENT_EVENTS[@]}"; do
    [[ "$e" == *"substage 'rework' auto-closed by parent end"* ]] && warn_count=$((warn_count + 1))
done
if (( warn_count == 1 )); then
    pass "M113-5b: exactly one auto-close warn event emitted"
else
    fail "M113-5b" "expected 1 auto-close warn, got $warn_count"
fi

# Verify the event level is 'warn'
warn_event=""
for e in "${_TUI_RECENT_EVENTS[@]}"; do
    [[ "$e" == *"auto-closed by parent end"* ]] && warn_event="$e" && break
done
event_level="${warn_event#*|}"
event_level="${event_level%%|*}"
if [[ "$event_level" == "warn" ]]; then
    pass "M113-5c: auto-close event level=warn"
else
    fail "M113-5c" "expected 'warn', got '$event_level' (event='$warn_event')"
fi

# =============================================================================
echo "=== M113-6: TUI_LIFECYCLE_V2=false → substage functions are no-ops ==="
_activate
TUI_LIFECYCLE_V2=false
# No parent opened; any side effects would be easy to detect.
tui_substage_begin "scout" "claude-haiku-4-5"

if [[ "$_TUI_CURRENT_SUBSTAGE_LABEL" == "" && "$_TUI_CURRENT_SUBSTAGE_START_TS" == "0" ]]; then
    pass "M113-6a: tui_substage_begin no-op under V2=false"
else
    fail "M113-6a" "opt-out violated (label='$_TUI_CURRENT_SUBSTAGE_LABEL', ts='$_TUI_CURRENT_SUBSTAGE_START_TS')"
fi

# Manually set and then call end — also a no-op (should not clear).
_TUI_CURRENT_SUBSTAGE_LABEL="poisoned"
_TUI_CURRENT_SUBSTAGE_START_TS=12345
tui_substage_end "poisoned"
if [[ "$_TUI_CURRENT_SUBSTAGE_LABEL" == "poisoned" && "$_TUI_CURRENT_SUBSTAGE_START_TS" == "12345" ]]; then
    pass "M113-6b: tui_substage_end no-op under V2=false"
else
    fail "M113-6b" "opt-out violated (label='$_TUI_CURRENT_SUBSTAGE_LABEL', ts='$_TUI_CURRENT_SUBSTAGE_START_TS')"
fi

# Reset for subsequent tests.
_TUI_CURRENT_SUBSTAGE_LABEL=""
_TUI_CURRENT_SUBSTAGE_START_TS=0

# Also verify auto-close helper respects V2=false.
_activate
TUI_LIFECYCLE_V2=false
tui_stage_begin "coder" "claude-opus-4-7"
_TUI_CURRENT_SUBSTAGE_LABEL="scout"
_TUI_CURRENT_SUBSTAGE_START_TS=999
tui_stage_end "coder" "claude-opus-4-7" "20/50" "30s" "PASS"
warn_count=0
for e in "${_TUI_RECENT_EVENTS[@]}"; do
    [[ "$e" == *"auto-closed by parent end"* ]] && warn_count=$((warn_count + 1))
done
if (( warn_count == 0 )); then
    pass "M113-6c: auto-close helper no-op under V2=false"
else
    fail "M113-6c" "expected 0 auto-close warns under V2=false, got $warn_count"
fi

# =============================================================================
echo "=== M113-7: _TUI_CURRENT_SUBSTAGE_LABEL is externally readable ==="
# M117 requirement: lib/common.sh must be able to consult the substage label
# without re-sourcing lib/tui_ops.sh. Verify by spawning a bash child that
# only inherits the environment and checking that the global is NOT exported
# (substage state is intentionally process-local), BUT is readable from the
# same shell after sourcing lib/tui.sh. Since lib/common.sh is sourced into
# the same shell as lib/tui.sh in the real pipeline, readability via shared
# globals is what matters.
_activate
TUI_LIFECYCLE_V2=true
tui_stage_begin "coder" "claude-opus-4-7"
tui_substage_begin "scout" "claude-haiku-4-5"
# The global is readable directly without re-sourcing anything.
readback="${_TUI_CURRENT_SUBSTAGE_LABEL}"
if [[ "$readback" == "scout" ]]; then
    pass "M113-7: _TUI_CURRENT_SUBSTAGE_LABEL readable from shared shell scope"
else
    fail "M113-7" "expected 'scout', got '$readback'"
fi
tui_substage_end "scout"
tui_stage_end "coder" "claude-opus-4-7" "25/50" "40s" "PASS"

# =============================================================================
echo "=== M113-8: substage JSON fields absent/empty when no substage active ==="
_activate
tui_stage_begin "coder" "claude-opus-4-7"
# No substage begun.
got_label=$(_json_field current_substage_label)
got_ts=$(_json_field current_substage_start_ts)
if [[ "$got_label" == "" ]]; then
    pass "M113-8a: current_substage_label is empty when no substage active"
else
    fail "M113-8a" "expected '', got '$got_label'"
fi
if [[ "$got_ts" == "0" ]]; then
    pass "M113-8b: current_substage_start_ts is 0 when no substage active"
else
    fail "M113-8b" "expected '0', got '$got_ts'"
fi

# =============================================================================
echo "=== M113-9: tui_substage_begin with empty label is a no-op ==="
_activate
TUI_LIFECYCLE_V2=true
tui_stage_begin "coder" "claude-opus-4-7"
# Capture state before the call.
pre_label="$_TUI_CURRENT_SUBSTAGE_LABEL"
pre_ts="$_TUI_CURRENT_SUBSTAGE_START_TS"
# Call with empty string — the guard [[ -z "$label" ]] && return 0 must fire.
tui_substage_begin "" "claude-haiku-4-5"
if [[ "$_TUI_CURRENT_SUBSTAGE_LABEL" == "$pre_label" ]]; then
    pass "M113-9a: empty label leaves _TUI_CURRENT_SUBSTAGE_LABEL unchanged ('$pre_label')"
else
    fail "M113-9a" "expected '$pre_label', got '$_TUI_CURRENT_SUBSTAGE_LABEL'"
fi
if [[ "$_TUI_CURRENT_SUBSTAGE_START_TS" == "$pre_ts" ]]; then
    pass "M113-9b: empty label leaves _TUI_CURRENT_SUBSTAGE_START_TS unchanged ($pre_ts)"
else
    fail "M113-9b" "expected $pre_ts, got '$_TUI_CURRENT_SUBSTAGE_START_TS'"
fi
tui_stage_end "coder" "claude-opus-4-7" "10/50" "15s" "PASS"

# =============================================================================
echo "=== M113-10: tui_substage_begin when _TUI_ACTIVE=false is a no-op ==="
_activate
_TUI_ACTIVE=false
TUI_LIFECYCLE_V2=true
# Globals should not be touched when TUI is inactive.
tui_substage_begin "scout" "claude-haiku-4-5"
if [[ "$_TUI_CURRENT_SUBSTAGE_LABEL" == "" ]]; then
    pass "M113-10a: _TUI_ACTIVE=false keeps _TUI_CURRENT_SUBSTAGE_LABEL empty"
else
    fail "M113-10a" "expected '', got '$_TUI_CURRENT_SUBSTAGE_LABEL'"
fi
if [[ "$_TUI_CURRENT_SUBSTAGE_START_TS" == "0" ]]; then
    pass "M113-10b: _TUI_ACTIVE=false keeps _TUI_CURRENT_SUBSTAGE_START_TS at 0"
else
    fail "M113-10b" "expected 0, got '$_TUI_CURRENT_SUBSTAGE_START_TS'"
fi
# Confirm tui_substage_end also no-ops under _TUI_ACTIVE=false.
_TUI_CURRENT_SUBSTAGE_LABEL="poisoned"
_TUI_CURRENT_SUBSTAGE_START_TS=77777
tui_substage_end "poisoned" "PASS"
if [[ "$_TUI_CURRENT_SUBSTAGE_LABEL" == "poisoned" && "$_TUI_CURRENT_SUBSTAGE_START_TS" == "77777" ]]; then
    pass "M113-10c: tui_substage_end no-op under _TUI_ACTIVE=false"
else
    fail "M113-10c" "expected globals unchanged, got label='$_TUI_CURRENT_SUBSTAGE_LABEL' ts='$_TUI_CURRENT_SUBSTAGE_START_TS'"
fi

# =============================================================================
echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
