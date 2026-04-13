#!/usr/bin/env bash
# Test: changelog_helpers.sh — _changelog_insert_after_unreleased
# Coverage gap: pre-existing blank line handling (M78 non-blocking note #5)
set -euo pipefail

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS=0
FAIL=0

pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*"; FAIL=$((FAIL + 1)); }

# Stub logging functions
log()     { :; }
warn()    { :; }
error()   { :; }
success() { :; }
header()  { :; }

# Source the library
# shellcheck source=../lib/changelog_helpers.sh
source "${TEKHTON_HOME}/lib/changelog_helpers.sh"

test_no_preexisting_blank() {
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' RETURN

    local changelog="${tmpdir}/CHANGELOG.md"
    cat > "$changelog" <<'EOF'
# Changelog

## [Unreleased]
Some existing content
EOF

    _changelog_insert_after_unreleased "$changelog" "- New feature"

    # Verify entry was inserted
    if grep -qF -- '- New feature' "$changelog"; then
        pass "Test 1a: entry inserted after [Unreleased]"
    else
        fail "Test 1a: entry not found"
    fi

    # Verify structure: header → blank → entry → existing content
    section=$(sed -n '/^\## \[Unreleased\]/,/Some existing/p' "$changelog")
    if echo "$section" | sed -n '2p' | grep -q '^$'; then
        pass "Test 1b: blank line separator added when none existed"
    else
        fail "Test 1b: no blank line between header and entry"
    fi
}

test_preexisting_blank() {
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' RETURN

    local changelog="${tmpdir}/CHANGELOG.md"
    cat > "$changelog" <<'EOF'
# Changelog

## [Unreleased]

Some existing content
EOF

    _changelog_insert_after_unreleased "$changelog" "- New feature"

    # Verify entry was inserted
    if grep -qF -- '- New feature' "$changelog"; then
        pass "Test 2a: entry inserted with pre-existing blank"
    else
        fail "Test 2a: entry not found"
    fi

    # Verify structure: header → entry → blank → existing content
    # (the pre-existing blank is preserved, but comes AFTER the entry)
    section=$(sed -n '/^\## \[Unreleased\]/,/Some existing/p' "$changelog")
    if echo "$section" | sed -n '2p' | grep -qF -- '- New feature'; then
        pass "Test 2b: entry placed directly after header (no new separator added)"
    else
        fail "Test 2b: entry not in expected position"
    fi

    # Count total blank lines between entry and existing content (should be exactly 1)
    blank_line_count=$(awk '/^- New feature/,/Some existing/{if(/^$/)print}' "$changelog" | wc -l)
    if [[ "$blank_line_count" -eq 1 ]]; then
        pass "Test 2c: only one blank line total (no double blank)"
    else
        fail "Test 2c: expected 1 blank line, got $blank_line_count"
    fi
}

test_no_unreleased_header() {
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' RETURN

    local changelog="${tmpdir}/CHANGELOG.md"
    cat > "$changelog" <<'EOF'
# Changelog

## [v1.0.0]
- Old feature
EOF

    _changelog_insert_after_unreleased "$changelog" "- New feature" || return 1

    # Verify entry was appended
    if tail -1 "$changelog" | grep -qF -- '- New feature'; then
        pass "Test 3a: entry appended when [Unreleased] not found"
    else
        fail "Test 3a: entry not appended"
        return 1
    fi

    # Verify by checking that the file has more lines than before (4+2=6)
    local linecount
    linecount=$(wc -l < "$changelog")
    if [[ "$linecount" -ge 6 ]]; then
        pass "Test 3b: entry appended with proper formatting"
    else
        fail "Test 3b: file doesn't have expected lines (got $linecount)"
        return 1
    fi
}

test_double_blank_prevention() {
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' RETURN

    local changelog="${tmpdir}/CHANGELOG.md"
    cat > "$changelog" <<'EOF'
# Changelog

## [Unreleased]

Previous bullet
EOF

    _changelog_insert_after_unreleased "$changelog" "- New bullet"

    # Check that we don't have double blanks anywhere
    # by looking for consecutive blank lines
    local has_double_blank
    has_double_blank=$(awk 'BEGIN{blank=0} /^$/{if(blank)exit 1; blank=1; next} {blank=0}' "$changelog" && echo "0" || echo "1")

    if [[ "$has_double_blank" == "0" ]]; then
        pass "Test 4: no consecutive blank lines (double blank bug fixed)"
    else
        fail "Test 4: found consecutive blank lines"
    fi
}

# Run all tests
echo "=== changelog_helpers tests ==="
test_no_preexisting_blank
test_preexisting_blank
test_no_unreleased_header
test_double_blank_prevention

echo
if [ "$FAIL" -gt 0 ]; then
    echo "FAILED: $FAIL test(s)"
    exit 1
else
    echo "PASSED: All tests ($PASS assertions)"
    exit 0
fi
