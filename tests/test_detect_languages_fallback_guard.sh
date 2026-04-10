#!/usr/bin/env bash
# Test: detect_languages CLAUDE.md fallback guard
# Verifies that fallback is skipped when file-based detection produces output
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
# Test 1: Project with source files AND CLAUDE.md should NOT use fallback
# =============================================================================
echo "=== Test: Fallback guard — file-based detection takes precedence ==="

HYBRID_DIR=$(make_proj "hybrid_project")

# Create source files (TypeScript)
echo '{"name":"my-app"}' > "$HYBRID_DIR/package.json"
echo '{"compilerOptions":{}}' > "$HYBRID_DIR/tsconfig.json"
touch "$HYBRID_DIR/index.ts" "$HYBRID_DIR/app.ts"

# ALSO create a CLAUDE.md with different language (Python)
cat > "$HYBRID_DIR/CLAUDE.md" << 'EOF'
# My Project

### 1. Project Identity

- Python
- A backend service using Django

### 2. Architecture

Standard service.
EOF

hybrid_langs=$(detect_languages "$HYBRID_DIR")

# Should detect TypeScript (file-based), NOT Python (from CLAUDE.md)
if echo "$hybrid_langs" | grep -q "^typescript|"; then
    pass "File-based detection detects TypeScript correctly"
else
    fail "File-based detection failed to detect TypeScript: $hybrid_langs"
fi

# Verify TypeScript is from manifest (package.json), not from CLAUDE.md
if echo "$hybrid_langs" | grep "^typescript|" | grep -q "package.json"; then
    pass "TypeScript correctly attributed to package.json (not CLAUDE.md)"
else
    fail "TypeScript manifest should be package.json: $hybrid_langs"
fi

# Should NOT detect Python (fallback should be skipped)
if echo "$hybrid_langs" | grep -q "^python|"; then
    fail "Fallback was used when file-based detection already produced output (double-emit of Python)"
else
    pass "Fallback correctly skipped when file-based detection produces output"
fi

# Verify no CLAUDE.md suffix in the output
if echo "$hybrid_langs" | grep -q "CLAUDE.md"; then
    fail "Output should not contain CLAUDE.md markers (fallback was used): $hybrid_langs"
else
    pass "No CLAUDE.md markers in output (fallback skipped)"
fi

# =============================================================================
# Test 2: Confidence levels are correct — file-based should be 'high'
# =============================================================================
echo "=== Test: Confidence levels — file-based detection ==="

conf=$(echo "$hybrid_langs" | grep "^typescript|" | cut -d'|' -f2)
if [[ "$conf" == "high" ]]; then
    pass "TypeScript confidence is 'high' (manifest + source files)"
else
    fail "TypeScript confidence should be 'high', got: $conf"
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
