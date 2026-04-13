#!/usr/bin/env bash
# Test: docs_agent.sh — _docs_extract_doc_responsibilities shared helper
# Extracted helper used by both _docs_extract_public_surface and _docs_prepare_template_vars (M78 non-blocking note #10)
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
# shellcheck source=../lib/docs_agent.sh
source "${TEKHTON_HOME}/lib/docs_agent.sh"

test_extract_basic_section() {
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' RETURN

    local rules_file="${tmpdir}/CLAUDE.md"
    cat > "$rules_file" <<'EOF'
# CLAUDE.md

## Section 1

Some content

## Documentation Responsibilities

- README.md
- docs/ directory
- API documentation

## Section 2

Other content
EOF

    local result
    result=$(_docs_extract_doc_responsibilities "$rules_file")

    if echo "$result" | grep -qF -- '- README.md'; then
        pass "Test 1a: extracted README.md from section"
    else
        fail "Test 1a: README.md not found in extracted section"
    fi

    if echo "$result" | grep -qF 'docs/' ; then
        pass "Test 1b: extracted docs/ path from section"
    else
        fail "Test 1b: docs/ path not found in extracted section"
    fi

    if ! echo "$result" | grep -q 'Section 2'; then
        pass "Test 1c: stopped at next ## header"
    else
        fail "Test 1c: included content from next section"
    fi
}

test_extract_case_insensitive() {
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' RETURN

    local rules_file="${tmpdir}/CLAUDE.md"
    cat > "$rules_file" <<'EOF'
# CLAUDE.md

## documentation responsibilities

- File1
- File2

## Next Section

Content
EOF

    local result
    result=$(_docs_extract_doc_responsibilities "$rules_file")

    if echo "$result" | grep -qF -- '- File1'; then
        pass "Test 2: case-insensitive matching works (lowercase)"
    else
        fail "Test 2: lowercase 'documentation responsibilities' not matched"
    fi
}

test_extract_empty_when_not_found() {
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' RETURN

    local rules_file="${tmpdir}/CLAUDE.md"
    cat > "$rules_file" <<'EOF'
# CLAUDE.md

## Section 1

Some content

## Section 2

Other content
EOF

    local result
    result=$(_docs_extract_doc_responsibilities "$rules_file")

    if [[ -z "$result" ]]; then
        pass "Test 3a: returns empty string when section not found"
    else
        fail "Test 3a: should return empty but got: $result"
    fi
}

test_extract_nonexistent_file() {
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' RETURN

    local rules_file="${tmpdir}/NONEXISTENT.md"

    local result
    result=$(_docs_extract_doc_responsibilities "$rules_file")

    if [[ -z "$result" ]]; then
        pass "Test 3b: returns empty for nonexistent file"
    else
        fail "Test 3b: should return empty for nonexistent file"
    fi
}

test_extract_header_exclusion() {
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' RETURN

    local rules_file="${tmpdir}/CLAUDE.md"
    cat > "$rules_file" <<'EOF'
# CLAUDE.md

## Documentation Responsibilities

- README.md
- docs/ directory
- Content to extract

## Section Notes

More content

## Next Section

Even more
EOF

    local result
    result=$(_docs_extract_doc_responsibilities "$rules_file")

    # Should include content and stop at next ##
    if echo "$result" | grep -qF 'Content to extract'; then
        pass "Test 4a: includes content from section"
    else
        fail "Test 4a: content not included"
    fi

    # Should exclude next sections (range stops at next ## line)
    if ! echo "$result" | grep -q 'More content'; then
        pass "Test 4b: excludes content from next section"
    else
        fail "Test 4b: should exclude content after first ## header after start"
    fi

    # The range ends at the first "^## " line after the start
    # So "## Section Notes" ends the range (matches ^## )
    if ! echo "$result" | grep -q 'Section Notes'; then
        pass "Test 4c: section header that ends range is excluded"
    else
        fail "Test 4c: should not include the header that ends the range"
    fi
}

test_extract_with_nested_headers() {
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' RETURN

    local rules_file="${tmpdir}/CLAUDE.md"
    cat > "$rules_file" <<'EOF'
# CLAUDE.md

## Documentation Responsibilities

### Sub-section

- File1
- File2

### Another Sub

- File3

## Next Main Section

Content
EOF

    local result
    result=$(_docs_extract_doc_responsibilities "$rules_file")

    # Should include ### headers within the section
    if echo "$result" | grep -q '###'; then
        pass "Test 5a: includes sub-headers within section"
    else
        fail "Test 5a: sub-headers should be included"
    fi

    # Should include content from sub-sections
    if echo "$result" | grep -qF -- '- File3'; then
        pass "Test 5b: includes content from all sub-sections"
    else
        fail "Test 5b: content from sub-sections not included"
    fi

    # Should exclude content from next main section (##)
    if ! echo "$result" | grep -q 'Next Main Section'; then
        pass "Test 5c: excludes next main section"
    else
        fail "Test 5c: should exclude next ## section"
    fi
}

test_extract_trim_behavior() {
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' RETURN

    local rules_file="${tmpdir}/CLAUDE.md"
    cat > "$rules_file" <<'EOF'
# CLAUDE.md

## Documentation Responsibilities

Content with leading spaces
More content

## Next Section
EOF

    local result
    result=$(_docs_extract_doc_responsibilities "$rules_file")

    # Should preserve content (sed doesn't trim by default)
    if echo "$result" | grep -q 'Content with leading spaces'; then
        pass "Test 6: preserves content formatting"
    else
        fail "Test 6: content should be preserved"
    fi
}

# Run all tests
echo "=== docs_agent_helpers tests ==="
test_extract_basic_section
test_extract_case_insensitive
test_extract_empty_when_not_found
test_extract_nonexistent_file
test_extract_header_exclusion
test_extract_with_nested_headers
test_extract_trim_behavior

echo
if [ "$FAIL" -gt 0 ]; then
    echo "FAILED: $FAIL test(s)"
    exit 1
else
    echo "PASSED: All tests ($PASS assertions)"
    exit 0
fi
