#!/usr/bin/env bash
# Test: detect_languages CLAUDE.md fallback with multiple languages
# Verifies that multiple languages in Project Identity bullets are extracted
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

# Source detection libraries
# shellcheck source=../lib/detect.sh
source "${TEKHTON_HOME}/lib/detect.sh"

# Helper: make a fresh project dir
make_proj() {
    local name="$1"
    local dir="${TEST_TMPDIR}/${name}"
    mkdir -p "$dir"
    echo "$dir"
}

# =============================================================================
# Test 1: CLAUDE.md with multiple language bullets in Project Identity
# =============================================================================
echo "=== Test: CLAUDE.md with multiple languages ==="

MULTI_DIR=$(make_proj "multi_lang_project")

# Create CLAUDE.md with multiple language bullets
cat > "$MULTI_DIR/CLAUDE.md" << 'EOF'
# Backend Service

### 1. Project Identity

- Go
- TypeScript (tools)
- Python (data pipeline)

### 2. Architecture

Microservices architecture.

### 3. Tech Details

Uses multiple languages.
EOF

multi_langs=$(detect_languages "$MULTI_DIR")

# Should detect all three languages
if echo "$multi_langs" | grep -q "^go|"; then
    pass "Go detected from CLAUDE.md"
else
    fail "Go NOT detected: $multi_langs"
fi

if echo "$multi_langs" | grep -q "^typescript|"; then
    pass "TypeScript detected from CLAUDE.md"
else
    fail "TypeScript NOT detected: $multi_langs"
fi

if echo "$multi_langs" | grep -q "^python|"; then
    pass "Python detected from CLAUDE.md"
else
    fail "Python NOT detected: $multi_langs"
fi

# All should be low confidence from CLAUDE.md
if echo "$multi_langs" | grep "^go|" | grep -q "|low|CLAUDE.md"; then
    pass "Go has low confidence from CLAUDE.md"
else
    fail "Go confidence should be low|CLAUDE.md: $multi_langs"
fi

if echo "$multi_langs" | grep "^typescript|" | grep -q "|low|CLAUDE.md"; then
    pass "TypeScript has low confidence from CLAUDE.md"
else
    fail "TypeScript confidence should be low|CLAUDE.md: $multi_langs"
fi

if echo "$multi_langs" | grep "^python|" | grep -q "|low|CLAUDE.md"; then
    pass "Python has low confidence from CLAUDE.md"
else
    fail "Python confidence should be low|CLAUDE.md: $multi_langs"
fi

# =============================================================================
# Test 2: CLAUDE.md with parenthetical descriptions in bullets
# =============================================================================
echo "=== Test: CLAUDE.md with parenthetical descriptions ==="

PAREN_DIR=$(make_proj "paren_project")

# Bullets with descriptions in parentheses
cat > "$PAREN_DIR/CLAUDE.md" << 'EOF'
# Web Application

### 1. Project Identity

- Rust (backend API)
- JavaScript (frontend)
- PHP (legacy admin)

### 2. Architecture

Multiple language codebase.
EOF

paren_langs=$(detect_languages "$PAREN_DIR")

# Should extract the language names, not the descriptions
if echo "$paren_langs" | grep -q "^rust|"; then
    pass "Rust extracted despite parenthetical description"
else
    fail "Rust NOT extracted: $paren_langs"
fi

if echo "$paren_langs" | grep -q "^javascript|"; then
    pass "JavaScript extracted despite parenthetical description"
else
    fail "JavaScript NOT extracted: $paren_langs"
fi

if echo "$paren_langs" | grep -q "^php|"; then
    pass "PHP extracted despite parenthetical description"
else
    fail "PHP NOT extracted: $paren_langs"
fi

# Verify no "backend API" or "frontend" as language names
if echo "$paren_langs" | grep -qi "backend\|frontend\|legacy"; then
    fail "Parenthetical descriptions should not be treated as languages: $paren_langs"
else
    pass "Descriptions correctly excluded from language names"
fi

# =============================================================================
# Test 3: Case insensitivity — mixed case in CLAUDE.md
# =============================================================================
echo "=== Test: Case insensitivity in language detection ==="

CASE_DIR=$(make_proj "case_project")

# Mixed case in CLAUDE.md
cat > "$CASE_DIR/CLAUDE.md" << 'EOF'
# Project

### 1. Project Identity

- TypeScript
- PYTHON
- kotlin

### 2. Details

Mixed case languages.
EOF

case_langs=$(detect_languages "$CASE_DIR")

# Should normalize to lowercase
if echo "$case_langs" | grep -q "^typescript|"; then
    pass "TypeScript (mixed case) normalized to lowercase"
else
    fail "TypeScript NOT detected: $case_langs"
fi

if echo "$case_langs" | grep -q "^python|"; then
    pass "Python (uppercase) normalized to lowercase"
else
    fail "Python NOT detected: $case_langs"
fi

if echo "$case_langs" | grep -q "^kotlin|"; then
    pass "Kotlin (lowercase) detected correctly"
else
    fail "Kotlin NOT detected: $case_langs"
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
