#!/usr/bin/env bash
# Test: architect.sh multi-line bullet joining for Out of Scope and
#       Design Doc Observations parsing (Bug 1 fix verification)
set -euo pipefail

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

FAIL=0

assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" != "$actual" ]; then
        echo "FAIL: $name — expected '$expected', got '$actual'"
        FAIL=1
    fi
}

assert_contains() {
    local name="$1" haystack="$2" needle="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        echo "FAIL: $name — '$needle' not found in output"
        FAIL=1
    fi
}

assert_not_contains() {
    local name="$1" haystack="$2" needle="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        echo "FAIL: $name — unexpected '$needle' found in output"
        FAIL=1
    fi
}

# ---------------------------------------------------------------------------
# Helper: implements the same bullet-joining logic as architect.sh
# This mirrors the fix exactly so we test the algorithm, not a copy.
# ---------------------------------------------------------------------------
parse_bullets() {
    local section="$1"
    local -a items=()
    local _current=""
    while IFS= read -r line; do
        local cleaned="${line#"${line%%[![:space:]]*}"}"
        [ -z "$cleaned" ] && continue
        if [[ "$cleaned" =~ ^[-*][[:space:]]+(.*) ]]; then
            if [ -n "$_current" ]; then
                items+=("$_current")
            fi
            _current="${BASH_REMATCH[1]}"
        else
            if [ -n "$_current" ]; then
                _current="${_current} ${cleaned}"
            else
                _current="$cleaned"
            fi
        fi
    done <<< "$section"
    if [ -n "$_current" ]; then
        items+=("$_current")
    fi
    # Print one item per line
    for item in "${items[@]}"; do
        printf '%s\n' "$item"
    done
}

# ---------------------------------------------------------------------------
# Test 1: Single-line bullets are parsed as individual entries
# ---------------------------------------------------------------------------
section="- Alpha observation
- Beta observation
- Gamma observation"

result=$(parse_bullets "$section")
count=$(echo "$result" | grep -c '^' || true)
assert_eq "single-line bullet count" "3" "$count"
assert_contains "single-line alpha" "$result" "Alpha observation"
assert_contains "single-line beta" "$result" "Beta observation"
assert_contains "single-line gamma" "$result" "Gamma observation"

# ---------------------------------------------------------------------------
# Test 2: Multi-line bullet continuation lines are joined to the bullet
# ---------------------------------------------------------------------------
section="- First bullet that continues
  on a second line
  and even a third line
- Second bullet single line"

result=$(parse_bullets "$section")
count=$(echo "$result" | grep -c '^' || true)
assert_eq "multi-line bullet count" "2" "$count"
assert_contains "multi-line joined content" "$result" "First bullet that continues on a second line and even a third line"
assert_contains "multi-line second bullet" "$result" "Second bullet single line"
# Continuation lines must NOT create additional entries — only 2 entries total
assert_eq "multi-line produces exactly 2 entries" "2" "$count"

# ---------------------------------------------------------------------------
# Test 3: Asterisk bullets are recognised as bullet starters
# ---------------------------------------------------------------------------
section="* Star bullet entry
* Another star entry"

result=$(parse_bullets "$section")
count=$(echo "$result" | grep -c '^' || true)
assert_eq "asterisk bullet count" "2" "$count"
assert_contains "star bullet first" "$result" "Star bullet entry"
assert_contains "star bullet second" "$result" "Another star entry"

# ---------------------------------------------------------------------------
# Test 4: Indented bullets are stripped of leading whitespace before parsing
# ---------------------------------------------------------------------------
section="  - Indented bullet entry
    continuation of indented
- Non-indented entry"

result=$(parse_bullets "$section")
count=$(echo "$result" | grep -c '^' || true)
assert_eq "indented bullet count" "2" "$count"
assert_contains "indented joined" "$result" "Indented bullet entry continuation of indented"
assert_contains "non-indented present" "$result" "Non-indented entry"

# ---------------------------------------------------------------------------
# Test 5: Placeholder entries are filtered out (None, N/A variants)
# ---------------------------------------------------------------------------
filter_placeholders() {
    local -a items=()
    while IFS= read -r entry; do
        [ -z "$entry" ] && continue
        echo "$entry" | grep -qiE '^\s*None\b' && continue
        echo "$entry" | grep -qiE '^\s*N/?A\b' && continue
        echo "$entry" | grep -qiE '^No (items?|observations?)\b' && continue
        echo "$entry" | grep -qE '^\s*-+\s*$' && continue
        items+=("$entry")
    done
    for item in "${items[@]+"${items[@]}"}"; do
        printf '%s\n' "$item"
    done
}

section="- None
- N/A
- No items
- Real observation here
- ----
- Another real observation"

raw_bullets=$(parse_bullets "$section")
result=$(echo "$raw_bullets" | filter_placeholders)
count=$(echo "$result" | grep -c '^' || true)
assert_eq "placeholder filtered count" "2" "$count"
assert_contains "real obs 1 present" "$result" "Real observation here"
assert_contains "real obs 2 present" "$result" "Another real observation"
assert_not_contains "None filtered" "$result" "None"
assert_not_contains "N/A filtered" "$result" "N/A"
assert_not_contains "No items filtered" "$result" "No items"

# ---------------------------------------------------------------------------
# Test 6: Empty section produces zero entries (no crash)
# ---------------------------------------------------------------------------
section=""
result=$(parse_bullets "$section")
assert_eq "empty section is empty" "" "$result"

# ---------------------------------------------------------------------------
# Test 7: Section with only blank lines produces zero entries
# ---------------------------------------------------------------------------
section="


"
result=$(parse_bullets "$section")
assert_eq "blank-only section is empty" "" "$result"

# ---------------------------------------------------------------------------
# Test 8: Real-world multi-line Out of Scope block (regression case)
# Simulates the actual corruption that was happening before the fix.
# Each continuation line was being treated as a separate entry, giving
# it its own [date | "task"] prefix in DRIFT_LOG.md.
# ---------------------------------------------------------------------------
oos_section="- Large-scale test reorganization — this is a substantial effort
  requiring dedicated sprint planning and stakeholder alignment
  before it can be scheduled
- Performance profiling suite — needs separate tooling"

result=$(parse_bullets "$oos_section")
count=$(echo "$result" | grep -c '^' || true)
assert_eq "regression oos count is 2 not 5" "2" "$count"
assert_contains "regression joined entry" "$result" "Large-scale test reorganization — this is a substantial effort requiring dedicated sprint planning and stakeholder alignment before it can be scheduled"
assert_contains "regression second entry" "$result" "Performance profiling suite — needs separate tooling"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
if [ "$FAIL" -ne 0 ]; then
    echo "ARCHITECT MULTILINE BULLET TESTS FAILED"
    exit 1
fi

echo "Architect multi-line bullet joining tests passed (8 tests)"
