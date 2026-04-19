#!/usr/bin/env bash
# Test: _init_pick_recommendation pure function + banner structure
set -euo pipefail

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS=0
FAIL=0

pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*"; FAIL=$((FAIL + 1)); }

# --- Stub functions required by init_report_banner.sh -------------------------
log()     { :; }
warn()    { :; }
error()   { :; }
success() { :; }
header()  { :; }
export GREEN="" BOLD="" NC="" YELLOW="" CYAN="" RED=""

# M101: init_report_banner.sh now uses output_format.sh functions instead of
# direct echo-e calls. Stub them so the test remains self-contained.
_out_color()  { printf '%s' "${1:-}"; }
out_section() { printf '── %s ──\n' "${1:-}"; }
out_banner()  { printf '%s\n' "${1:-}"; shift || true; while [[ $# -ge 2 ]]; do printf '  %s: %s\n' "$1" "$2"; shift 2; done; }
out_msg()     { printf '%s\n' "$*"; }

# Stub _is_utf8_terminal — assume UTF-8 for testing
_is_utf8_terminal() { return 0; }

# Stub _build_box_hline — simple repeater
_build_box_hline() {
    local w="$1" ch="$2" line="" i=0
    while [[ "$i" -lt "$w" ]]; do line="${line}${ch}"; i=$((i + 1)); done
    echo "$line"
}

# Stub _best_command for attention counting
_best_command() { echo ""; }

# Stub _is_watchtower_enabled — default to disabled
_is_watchtower_enabled() { return 1; }

# Source the banner file
# shellcheck source=../lib/init_report_banner.sh
source "${TEKHTON_HOME}/lib/init_report_banner.sh"

# =============================================================================
# Test 1: zero files, no manifest, no pending → --plan
# =============================================================================
echo "=== Recommendation: zero files ==="

result=$(_init_pick_recommendation 0 false false)
expected_cmd="tekhton --plan \"goal\""
actual_cmd=$(echo "$result" | cut -d'|' -f1)

if [[ "$actual_cmd" == "$expected_cmd" ]]; then
    pass "zero files: recommends --plan"
else
    fail "zero files: expected '${expected_cmd}', got '${actual_cmd}'"
fi

# =============================================================================
# Test 2: small project (10 files), no manifest → --plan
# =============================================================================
echo "=== Recommendation: small project ==="

result=$(_init_pick_recommendation 10 false false)
actual_cmd=$(echo "$result" | cut -d'|' -f1)

if [[ "$actual_cmd" == "$expected_cmd" ]]; then
    pass "small project: recommends --plan"
else
    fail "small project: expected '${expected_cmd}', got '${actual_cmd}'"
fi

# =============================================================================
# Test 3: large project (100 files), no manifest → --plan-from-index
# =============================================================================
echo "=== Recommendation: large project ==="

result=$(_init_pick_recommendation 100 false false)
expected_cmd="tekhton --plan-from-index"
actual_cmd=$(echo "$result" | cut -d'|' -f1)

if [[ "$actual_cmd" == "$expected_cmd" ]]; then
    pass "large project: recommends --plan-from-index"
else
    fail "large project: expected '${expected_cmd}', got '${actual_cmd}'"
fi

# =============================================================================
# Test 4: large project with pending milestones → tekhton (run next)
# =============================================================================
echo "=== Recommendation: pending milestones ==="

result=$(_init_pick_recommendation 100 true true)
expected_cmd="tekhton"
actual_cmd=$(echo "$result" | cut -d'|' -f1)

if [[ "$actual_cmd" == "$expected_cmd" ]]; then
    pass "pending milestones: recommends tekhton (run next)"
else
    fail "pending milestones: expected '${expected_cmd}', got '${actual_cmd}'"
fi

# =============================================================================
# Test 5: alternates are populated (large project, no manifest)
# =============================================================================
echo "=== Recommendation: alternates present ==="

result=$(_init_pick_recommendation 100 false false)
alt1=$(echo "$result" | cut -d'|' -f3)
_alt2=$(echo "$result" | cut -d'|' -f4)

if [[ -n "$alt1" ]]; then
    pass "alternates populated: alt1='${alt1}'"
else
    fail "alternates empty for large project"
fi

# =============================================================================
# Test 6: Banner fixture — emit_init_summary output structure
# =============================================================================
echo "=== Banner structure ==="

TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

# Set up fake project dir
PROJ="${TEST_TMPDIR}/myproj"
mkdir -p "$PROJ"

# Populate _INIT_FILES_WRITTEN
_INIT_FILES_WRITTEN=(
    ".claude/pipeline.conf|primary config"
    ".claude/agents/coder.md|coder role"
    "INIT_REPORT.md|detection report"
)

banner_output=$(emit_init_summary "$PROJ" "python|high|pyproject.toml" \
    "django|python|pyproject.toml" \
    "test|pytest|pyproject.toml|high" \
    "api-service" 42 2>&1)

if echo "$banner_output" | grep -q "What Tekhton learned"; then
    pass "banner contains 'What Tekhton learned' section"
else
    fail "banner missing 'What Tekhton learned' section"
fi

if echo "$banner_output" | grep -q "What Tekhton wrote"; then
    pass "banner contains 'What Tekhton wrote' section"
else
    fail "banner missing 'What Tekhton wrote' section"
fi

if echo "$banner_output" | grep -q "What's next"; then
    pass "banner contains 'What\\'s next' section"
else
    fail "banner missing 'What\\'s next' section"
fi

# Verify file list appears
if echo "$banner_output" | grep -q "pipeline.conf"; then
    pass "banner lists pipeline.conf in files written"
else
    fail "banner missing pipeline.conf in files written"
fi

# Verify recommendation arrow
if echo "$banner_output" | grep -qE "(▶|>)"; then
    pass "banner has recommendation arrow marker"
else
    fail "banner missing recommendation arrow marker"
fi

# =============================================================================
# Test 7: NO_COLOR fallback uses ASCII
# =============================================================================
echo "=== NO_COLOR fallback ==="

_INIT_FILES_WRITTEN=("test.md|test file")
no_color_output=$(NO_COLOR=1 emit_init_summary "$PROJ" "" "" "" "custom" 0 2>&1)

if echo "$no_color_output" | grep -q '\*'; then
    pass "NO_COLOR uses ASCII bullet"
else
    # Check for = divider instead of ━
    if echo "$no_color_output" | grep -q '===='; then
        pass "NO_COLOR uses ASCII divider"
    else
        fail "NO_COLOR fallback not working"
    fi
fi

# =============================================================================
# Test 8: _init_render_files_written truncation — >8 entries shows "plus N more"
# =============================================================================
echo "=== Files written: truncation at 8 ==="

_INIT_FILES_WRITTEN=(
    "file1.txt|desc1"
    "file2.txt|desc2"
    "file3.txt|desc3"
    "file4.txt|desc4"
    "file5.txt|desc5"
    "file6.txt|desc6"
    "file7.txt|desc7"
    "file8.txt|desc8"
    "file9.txt|desc9"
    "file10.txt|desc10"
)

trunc_output=$(_init_render_files_written "*")

# Should list exactly 8 entries (file1..file8)
shown_count=$(echo "$trunc_output" | grep -c '^\s*\*' || true)
if [[ "$shown_count" -eq 9 ]]; then
    # 8 file lines + 1 "plus N more" line = 9 bullet lines
    pass "truncation: 9 bullet lines total (8 files + 1 overflow)"
else
    fail "truncation: expected 9 bullet lines, got ${shown_count}"
fi

# Should NOT show file9 or file10 as a file entry
if echo "$trunc_output" | grep -q 'file9.txt'; then
    fail "truncation: file9.txt should not appear in output"
else
    pass "truncation: file9.txt correctly suppressed"
fi

# Should show "plus 2 more"
if echo "$trunc_output" | grep -q '\.\.\.plus 2 more'; then
    pass "truncation: overflow line shows '...plus 2 more'"
else
    fail "truncation: overflow line missing or wrong count; output: $(echo "$trunc_output" | grep 'plus' || echo '(none)')"
fi

# =============================================================================
# Test 9: _init_render_files_written no truncation — exactly 8 entries, no overflow line
# =============================================================================
echo "=== Files written: no truncation at exactly 8 ==="

_INIT_FILES_WRITTEN=(
    "a.txt|da"
    "b.txt|db"
    "c.txt|dc"
    "d.txt|dd"
    "e.txt|de"
    "f.txt|df"
    "g.txt|dg"
    "h.txt|dh"
)

exact_output=$(_init_render_files_written "*")

if echo "$exact_output" | grep -q '\.\.\.plus'; then
    fail "no-truncation: overflow line should not appear for exactly 8 entries"
else
    pass "no-truncation: no overflow line for exactly 8 entries"
fi

shown_exact=$(echo "$exact_output" | grep -c '^\s*\*' || true)
if [[ "$shown_exact" -eq 8 ]]; then
    pass "no-truncation: exactly 8 bullet lines shown"
else
    fail "no-truncation: expected 8 bullet lines, got ${shown_exact}"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "────────────────────────────────────────"
echo "  Passed: ${PASS}  Failed: ${FAIL}"
echo "────────────────────────────────────────"

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
