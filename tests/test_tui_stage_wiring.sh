#!/usr/bin/env bash
# =============================================================================
# test_tui_stage_wiring.sh — M107 — verify pipeline stage wiring to the TUI
# protocol API (tui_stage_begin / tui_stage_end).
#
# Covers the labels emitted by tekhton.sh, stages/coder.sh, stages/review.sh,
# and lib/finalize.sh after M107 wiring, plus a regression guard that raw
# internal stage names (e.g. "test_verify") do not silently produce pills
# that mismatch the labels get_display_stage_order advertises.
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
error()      { :; }
success()     { :; }
header()      { :; }
log_verbose() { :; }

# shellcheck disable=SC1091
source "${TEKHTON_HOME}/lib/tui.sh"
# shellcheck disable=SC1091
source "${TEKHTON_HOME}/lib/pipeline_order.sh"

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
}

_stages_complete_labels_csv() {
    # Extracts the label field from each stages_complete JSON entry in order.
    python3 -c "
import json, sys
d = json.load(open('$_TUI_STATUS_FILE'))
labels = [s.get('label','') for s in d.get('stages_complete', [])]
print(','.join(labels))
" 2>/dev/null
}

# =============================================================================
echo "=== Test 1: intake stage produces an 'intake' entry in stages_complete ==="
_activate
tui_stage_begin "intake" "claude-sonnet-4-6"
tui_stage_end "intake" "claude-sonnet-4-6" "5/10" "12s" "PASS"

labels=$(_stages_complete_labels_csv)
if [[ "$labels" == "intake" ]]; then
    pass "intake stage emitted with label='intake'"
else
    fail "intake stage label" "expected 'intake', got '$labels'"
fi

# =============================================================================
echo "=== Test 2: raw internal 'test_verify' label is a regression guard ==="
# Simulate a buggy caller that passes the raw internal stage name instead of
# the display label. The pill bar MUST NOT end up with a 'tester' entry —
# callers are required to go through get_stage_display_label.
_activate
tui_stage_begin "test_verify" "claude-sonnet-4-6"
tui_stage_end "test_verify" "claude-sonnet-4-6" "10/30" "60s" ""

labels=$(_stages_complete_labels_csv)
if [[ "$labels" == "tester" ]]; then
    fail "raw internal name regression" \
         "tui_stage_begin 'test_verify' created a 'tester' pill (should not)"
elif [[ "$labels" == "test_verify" ]]; then
    pass "raw internal name 'test_verify' does not silently alias to 'tester'"
else
    fail "test_verify raw-name pill" "expected 'test_verify', got '$labels'"
fi

# =============================================================================
echo "=== Test 3: two rework cycles → one pill entry, two stages_complete ==="
_activate
tui_stage_begin "rework" "claude-opus-4-7"
tui_stage_end   "rework" "claude-opus-4-7" "20/70" "90s" ""
tui_stage_begin "rework" "claude-opus-4-7"
tui_stage_end   "rework" "claude-opus-4-7" "15/70" "60s" ""

rework_pill_count=0
for _s in "${_TUI_STAGE_ORDER[@]}"; do
    [[ "$_s" == "rework" ]] && rework_pill_count=$((rework_pill_count + 1))
done

if [[ "$rework_pill_count" -eq 1 ]]; then
    pass "_TUI_STAGE_ORDER contains exactly one 'rework' entry after two cycles"
else
    fail "_TUI_STAGE_ORDER rework count" \
         "expected 1, got $rework_pill_count (order=${_TUI_STAGE_ORDER[*]})"
fi

rework_complete_count=0
python3 -c "
import json
d = json.load(open('$_TUI_STATUS_FILE'))
c = sum(1 for s in d.get('stages_complete', []) if s.get('label') == 'rework')
print(c)
" > "$TMPDIR/rework_count.txt" 2>/dev/null
rework_complete_count=$(cat "$TMPDIR/rework_count.txt")

if [[ "$rework_complete_count" -eq 2 ]]; then
    pass "_TUI_STAGES_COMPLETE contains two 'rework' entries after two cycles"
else
    fail "stages_complete rework count" \
         "expected 2, got $rework_complete_count"
fi

# =============================================================================
echo "=== Test 4: wrap-up stage wiring (begin + end produces pill entry) ==="
_activate
tui_stage_begin "wrap-up" ""
tui_stage_end   "wrap-up" "" "" "" "SUCCESS"

labels=$(_stages_complete_labels_csv)
if [[ "$labels" == "wrap-up" ]]; then
    pass "wrap-up stage emitted with label='wrap-up'"
else
    fail "wrap-up stage label" "expected 'wrap-up', got '$labels'"
fi

# Verify wrap-up verdict was propagated
verdict=$(python3 -c "
import json
d = json.load(open('$_TUI_STATUS_FILE'))
stages = d.get('stages_complete', [])
print(stages[0].get('verdict') if stages else '')
" 2>/dev/null)
if [[ "$verdict" == "SUCCESS" ]]; then
    pass "wrap-up stage carries SUCCESS verdict"
else
    fail "wrap-up verdict" "expected 'SUCCESS', got '$verdict'"
fi

# =============================================================================
echo "=== Test 5: get_display_stage_order output ends with 'wrap-up' ==="
# Standard configuration
unset SKIP_SECURITY SKIP_DOCS
export INTAKE_AGENT_ENABLED=true
export SECURITY_AGENT_ENABLED=true
export DOCS_AGENT_ENABLED=false
order=$(get_display_stage_order)
last=$(echo "$order" | awk '{print $NF}')
if [[ "$last" == "wrap-up" ]]; then
    pass "standard order ends with 'wrap-up' (order='$order')"
else
    fail "standard order suffix" "expected 'wrap-up', got '$last' (order='$order')"
fi

# test_first order
export PIPELINE_ORDER=test_first
order=$(get_display_stage_order)
last=$(echo "$order" | awk '{print $NF}')
if [[ "$last" == "wrap-up" ]]; then
    pass "test_first order ends with 'wrap-up' (order='$order')"
else
    fail "test_first order suffix" "expected 'wrap-up', got '$last' (order='$order')"
fi

# With security disabled
export PIPELINE_ORDER=standard
export SECURITY_AGENT_ENABLED=false
order=$(get_display_stage_order)
last=$(echo "$order" | awk '{print $NF}')
if [[ "$last" == "wrap-up" ]]; then
    pass "order with security disabled still ends with 'wrap-up' (order='$order')"
else
    fail "order-no-security suffix" "expected 'wrap-up', got '$last'"
fi

# With docs enabled
export SECURITY_AGENT_ENABLED=true
export DOCS_AGENT_ENABLED=true
order=$(get_display_stage_order)
last=$(echo "$order" | awk '{print $NF}')
if [[ "$last" == "wrap-up" ]]; then
    pass "order with docs enabled still ends with 'wrap-up' (order='$order')"
else
    fail "order-with-docs suffix" "expected 'wrap-up', got '$last'"
fi

# =============================================================================
echo "=== Test 6: get_stage_display_label handles all wired stages ==="
_check_label() {
    local in="$1" expected="$2"
    local got
    got=$(get_stage_display_label "$in")
    if [[ "$got" == "$expected" ]]; then
        pass "get_stage_display_label('$in') → '$expected'"
    else
        fail "display label for '$in'" "expected '$expected', got '$got'"
    fi
}
_check_label "intake"      "intake"
_check_label "scout"       "scout"
_check_label "coder"       "coder"
_check_label "test_verify" "tester"
_check_label "test_write"  "tester-write"
_check_label "security"    "security"
_check_label "review"      "review"
_check_label "docs"        "docs"
_check_label "rework"      "rework"
_check_label "wrap_up"     "wrap-up"
_check_label "wrap-up"     "wrap-up"

echo ""
echo "=== Summary: ${PASS} passed, ${FAIL} failed ==="
[[ "$FAIL" -eq 0 ]]
