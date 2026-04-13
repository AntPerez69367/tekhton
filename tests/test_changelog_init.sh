#!/usr/bin/env bash
# Test: Milestone 77 — changelog_init_if_missing
set -euo pipefail

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS=0
FAIL=0

pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*"; FAIL=$((FAIL + 1)); }

TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

# Stub logging functions
log()     { :; }
warn()    { :; }
error()   { :; }
success() { :; }
header()  { :; }

# Source changelog library (and its helpers)
# shellcheck source=../lib/changelog.sh
source "${TEKHTON_HOME}/lib/changelog.sh"

# =============================================================================
# Test: CHANGELOG_ENABLED=true + no existing file → stub created
# =============================================================================
echo "=== init: stub created when enabled ==="
PROJ="${TEST_TMPDIR}/enabled"
mkdir -p "$PROJ"

CHANGELOG_ENABLED=true CHANGELOG_FILE=CHANGELOG.md \
    CHANGELOG_INIT_IF_MISSING=true \
    changelog_init_if_missing "$PROJ"

if [[ -f "$PROJ/CHANGELOG.md" ]]; then
    pass "CHANGELOG.md created"
else
    fail "CHANGELOG.md not created"
fi

# Verify canonical header content
if grep -q '# Changelog' "$PROJ/CHANGELOG.md"; then
    pass "has # Changelog header"
else
    fail "missing # Changelog header"
fi

if grep -q 'Keep a Changelog' "$PROJ/CHANGELOG.md"; then
    pass "has Keep a Changelog reference"
else
    fail "missing Keep a Changelog reference"
fi

if grep -q 'Semantic Versioning' "$PROJ/CHANGELOG.md"; then
    pass "has Semantic Versioning reference"
else
    fail "missing Semantic Versioning reference"
fi

if grep -q '## \[Unreleased\]' "$PROJ/CHANGELOG.md"; then
    pass "has [Unreleased] section"
else
    fail "missing [Unreleased] section"
fi

# =============================================================================
# Test: CHANGELOG_ENABLED=false → no stub
# =============================================================================
echo "=== init: no stub when disabled ==="
PROJ="${TEST_TMPDIR}/disabled"
mkdir -p "$PROJ"

CHANGELOG_ENABLED=false CHANGELOG_FILE=CHANGELOG.md \
    CHANGELOG_INIT_IF_MISSING=true \
    changelog_init_if_missing "$PROJ"

if [[ ! -f "$PROJ/CHANGELOG.md" ]]; then
    pass "no CHANGELOG.md when disabled"
else
    fail "CHANGELOG.md created despite CHANGELOG_ENABLED=false"
fi

# =============================================================================
# Test: CHANGELOG_INIT_IF_MISSING=false → no stub
# =============================================================================
echo "=== init: no stub when init_if_missing=false ==="
PROJ="${TEST_TMPDIR}/no_init"
mkdir -p "$PROJ"

CHANGELOG_ENABLED=true CHANGELOG_FILE=CHANGELOG.md \
    CHANGELOG_INIT_IF_MISSING=false \
    changelog_init_if_missing "$PROJ"

if [[ ! -f "$PROJ/CHANGELOG.md" ]]; then
    pass "no CHANGELOG.md when init_if_missing=false"
else
    fail "CHANGELOG.md created despite CHANGELOG_INIT_IF_MISSING=false"
fi

# =============================================================================
# Test: existing CHANGELOG.md → untouched
# =============================================================================
echo "=== init: existing file untouched ==="
PROJ="${TEST_TMPDIR}/existing"
mkdir -p "$PROJ"
echo "# My Custom Changelog" > "$PROJ/CHANGELOG.md"

CHANGELOG_ENABLED=true CHANGELOG_FILE=CHANGELOG.md \
    CHANGELOG_INIT_IF_MISSING=true \
    changelog_init_if_missing "$PROJ"

content=$(cat "$PROJ/CHANGELOG.md")
if [[ "$content" == "# My Custom Changelog" ]]; then
    pass "existing CHANGELOG.md preserved"
else
    fail "existing CHANGELOG.md was overwritten"
fi

# =============================================================================
# Test: custom CHANGELOG_FILE path
# =============================================================================
echo "=== init: custom file path ==="
PROJ="${TEST_TMPDIR}/custom_path"
mkdir -p "$PROJ"

CHANGELOG_ENABLED=true CHANGELOG_FILE=CHANGES.md \
    CHANGELOG_INIT_IF_MISSING=true \
    changelog_init_if_missing "$PROJ"

if [[ -f "$PROJ/CHANGES.md" ]]; then
    pass "custom CHANGES.md created"
else
    fail "custom CHANGES.md not created"
fi

if [[ ! -f "$PROJ/CHANGELOG.md" ]]; then
    pass "no default CHANGELOG.md created"
else
    fail "default CHANGELOG.md created despite custom path"
fi

# =============================================================================
# Summary
# =============================================================================
echo
echo "Results: ${PASS} passed, ${FAIL} failed"

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
