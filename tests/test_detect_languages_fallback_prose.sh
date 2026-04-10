#!/usr/bin/env bash
# Test: detect_languages CLAUDE.md fallback with prose (grep -oiE fallback)
# Verifies that the secondary grep pattern extracts languages from prose when bullets don't match
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
# Test 1: CLAUDE.md with languages in prose (no pure bullet pattern)
# =============================================================================
echo "=== Test: CLAUDE.md prose fallback — languages in description ==="

PROSE_DIR=$(make_proj "prose_project")

# Languages mentioned in prose, not as pure bullets
cat > "$PROSE_DIR/CLAUDE.md" << 'EOF'
# Data Pipeline System

### 1. Project Identity

A data pipeline written in Go and Rust that processes data using Python scripts.
The system uses TypeScript for CLI tooling and JavaScript for monitoring dashboards.
Primary focus is on building robust Go microservices with Rust performance optimizations.

### 2. Architecture

Three-tier architecture.
EOF

prose_langs=$(detect_languages "$PROSE_DIR")

# The fallback grep -oiE pattern should find these languages in prose
if echo "$prose_langs" | grep -q "^go|"; then
    pass "Go detected from prose (fallback grep pattern)"
else
    fail "Go NOT detected from prose: $prose_langs"
fi

if echo "$prose_langs" | grep -q "^rust|"; then
    pass "Rust detected from prose (fallback grep pattern)"
else
    fail "Rust NOT detected from prose: $prose_langs"
fi

if echo "$prose_langs" | grep -q "^python|"; then
    pass "Python detected from prose (fallback grep pattern)"
else
    fail "Python NOT detected from prose: $prose_langs"
fi

if echo "$prose_langs" | grep -q "^typescript|"; then
    pass "TypeScript detected from prose (fallback grep pattern)"
else
    fail "TypeScript NOT detected from prose: $prose_langs"
fi

if echo "$prose_langs" | grep -q "^javascript|"; then
    pass "JavaScript detected from prose (fallback grep pattern)"
else
    fail "JavaScript NOT detected from prose: $prose_langs"
fi

# All should be low confidence from CLAUDE.md
if echo "$prose_langs" | grep "^go|" | grep -q "|low|CLAUDE.md"; then
    pass "Go has low confidence from CLAUDE.md"
else
    fail "Go should have low|CLAUDE.md confidence: $prose_langs"
fi

# =============================================================================
# Test 2: CLAUDE.md with mixed bullet and prose format
# (Bullets take precedence — prose fallback only used when NO bullets exist)
# =============================================================================
echo "=== Test: CLAUDE.md mixed format — bullets take precedence ==="

MIXED_DIR=$(make_proj "mixed_format_project")

# Both bullet format and prose mentions
cat > "$MIXED_DIR/CLAUDE.md" << 'EOF'
# Cloud Application

### 1. Project Identity

- Kotlin for Android app
- Swift for iOS

We also use Python for backend data processing and have some Elixir/OTP services.

### 2. Architecture

Cross-platform mobile with backend.
EOF

mixed_langs=$(detect_languages "$MIXED_DIR")

# When bullets exist, ONLY bullets are used (prose is ignored by design)
if echo "$mixed_langs" | grep -q "^kotlin|"; then
    pass "Kotlin detected from bullet"
else
    fail "Kotlin NOT detected: $mixed_langs"
fi

if echo "$mixed_langs" | grep -q "^swift|"; then
    pass "Swift detected from bullet"
else
    fail "Swift NOT detected: $mixed_langs"
fi

# Python and Elixir are only in prose, so they should NOT be detected
# because bullets take precedence
if echo "$mixed_langs" | grep -q "^python|"; then
    fail "Python should NOT be detected (bullets take precedence over prose)"
else
    pass "Python correctly not detected (bullets take precedence)"
fi

if echo "$mixed_langs" | grep -q "^elixir|"; then
    fail "Elixir should NOT be detected (bullets take precedence over prose)"
else
    pass "Elixir correctly not detected (bullets take precedence)"
fi

# =============================================================================
# Test 3: Deduplication — same language from prose appears once
# =============================================================================
echo "=== Test: Deduplication — same language mentioned multiple times ==="

DUPE_DIR=$(make_proj "dupe_project")

# TypeScript mentioned multiple times in prose
cat > "$DUPE_DIR/CLAUDE.md" << 'EOF'
# Full Stack Service

### 1. Project Identity

Implemented entirely in TypeScript. The frontend is TypeScript/React, and the backend is TypeScript/Node.js.
All tooling is also written in TypeScript for consistency.

### 2. Architecture

Unified TypeScript codebase.
EOF

dupe_langs=$(detect_languages "$DUPE_DIR")

# Count occurrences of typescript in output (should be 1, not 3)
ts_count=$(echo "$dupe_langs" | grep -c "^typescript|" || true)

if [[ "$ts_count" -eq 1 ]]; then
    pass "TypeScript appears once despite multiple mentions in prose"
else
    fail "TypeScript should appear once but appears $ts_count times: $dupe_langs"
fi

# =============================================================================
# Test 4: Prose with language names as part of larger words (false positives)
# =============================================================================
echo "=== Test: Case-insensitive extraction doesn't match partial words ==="

WORD_DIR=$(make_proj "word_project")

# This section mentions "python" in context but shouldn't match "typescript" in "typescript-like"
cat > "$WORD_DIR/CLAUDE.md" << 'EOF'
# Analysis Tool

### 1. Project Identity

Built with Go for maximum performance. Our Go implementation handles all computation.
Uses a Kotlin-based reporting system for analytics.

### 2. Architecture

High-performance Go services.
EOF

word_langs=$(detect_languages "$WORD_DIR")

# Should detect Go and Kotlin
if echo "$word_langs" | grep -q "^go|"; then
    pass "Go detected from prose"
else
    fail "Go NOT detected: $word_langs"
fi

if echo "$word_langs" | grep -q "^kotlin|"; then
    pass "Kotlin detected from prose"
else
    fail "Kotlin NOT detected: $word_langs"
fi

# Should NOT detect false positives (no typescript, python, etc.)
if echo "$word_langs" | grep -qE "^(typescript|python|ruby|php|haskell|elixir|dart|swift|rust|java|javascript)\|"; then
    # Filter to what we expected
    unexpected=$(echo "$word_langs" | grep -vE "^(go|kotlin)\|" || true)
    if [[ -n "$unexpected" ]]; then
        fail "Unexpected language detection: $unexpected"
    else
        pass "Only expected languages detected"
    fi
else
    pass "No false positive language detection"
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
