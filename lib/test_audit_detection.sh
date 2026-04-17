#!/usr/bin/env bash
set -euo pipefail
# =============================================================================
# test_audit_detection.sh — Shell-based orphan and weakening detection
#
# Sourced by tekhton.sh — do not run directly.
# Expects: common.sh sourced first.
#
# Provides:
#   _detect_orphaned_tests — Shell-based orphan detection (no agent needed)
#   _detect_test_weakening — Shell-based weakening detection via git diff
#
# Reads globals: _AUDIT_TEST_FILES, _AUDIT_DELETED_FILES
# Writes globals: _AUDIT_ORPHAN_FINDINGS, _AUDIT_WEAKENING_FINDINGS
# =============================================================================

# --- Orphan detection (pure shell) -------------------------------------------

# _detect_orphaned_tests [test_files] [deleted_files]
# For each test file, extract import/require statements and check if they
# reference deleted modules. Also checks for renamed/moved files.
# Args override globals for testability. Defaults: _AUDIT_TEST_FILES, _AUDIT_DELETED_FILES
# Sets: _AUDIT_ORPHAN_FINDINGS (multiline, one finding per line)
# shellcheck disable=SC2120  # Args are optional overrides; callers use globals
_detect_orphaned_tests() {
    _AUDIT_ORPHAN_FINDINGS=""
    local test_files="${1:-${_AUDIT_TEST_FILES:-}}"
    local deleted_files="${2:-${_AUDIT_DELETED_FILES:-}}"

    [[ -z "$test_files" ]] && return
    [[ -z "$deleted_files" ]] && return

    while IFS= read -r test_file; do
        [[ -z "$test_file" ]] && continue
        [[ ! -f "$test_file" ]] && continue

        # Extract import targets (Python, JS/TS, Go patterns)
        local imports=""
        # Python: from X import / import X
        imports=$(grep -oP '(?:from\s+|import\s+)[\w.]+' "$test_file" 2>/dev/null || true)
        # JS/TS: require('X') / import ... from 'X'
        local js_imports
        js_imports=$(grep -oP "(?:require\s*\(\s*['\"]|from\s+['\"])([^'\"]+)" "$test_file" 2>/dev/null || true)
        if [[ -n "$js_imports" ]]; then
            imports="${imports}
${js_imports}"
        fi

        # Check each deleted file against imports
        while IFS= read -r deleted; do
            [[ -z "$deleted" ]] && continue
            local deleted_basename
            deleted_basename=$(basename "$deleted")
            local deleted_noext="${deleted_basename%.*}"

            # Check if the test file references the deleted module
            if echo "$imports" | grep -qF "$deleted_noext" 2>/dev/null; then
                _AUDIT_ORPHAN_FINDINGS="${_AUDIT_ORPHAN_FINDINGS}
ORPHAN: ${test_file} imports deleted module '${deleted}'"
            fi
        done <<< "$deleted_files"
    done <<< "$test_files"

    # Trim leading newline
    _AUDIT_ORPHAN_FINDINGS="${_AUDIT_ORPHAN_FINDINGS#$'\n'}"
    export _AUDIT_ORPHAN_FINDINGS
}

# --- Weakening detection (pure shell on git diff) ----------------------------

# _detect_test_weakening
# For each MODIFIED (not newly created) test file, analyze the diff for:
#   - Removed assertions
#   - Broadened assertions (specific → generic)
#   - Removed test functions
# Reads: _AUDIT_TEST_FILES
# Sets: _AUDIT_WEAKENING_FINDINGS (multiline, one finding per line)
_detect_test_weakening() {
    _AUDIT_WEAKENING_FINDINGS=""

    [[ -z "${_AUDIT_TEST_FILES:-}" ]] && return

    if ! git rev-parse --git-dir &>/dev/null; then
        return
    fi

    while IFS= read -r test_file; do
        [[ -z "$test_file" ]] && continue
        [[ ! -f "$test_file" ]] && continue

        # Skip newly created files (no weakening possible)
        if ! git show "HEAD:${test_file}" &>/dev/null; then
            continue
        fi

        local diff_output
        diff_output=$(git diff HEAD -- "$test_file" 2>/dev/null || true)
        [[ -z "$diff_output" ]] && continue

        # Count removed vs added assertion lines
        local removed_asserts=0
        local added_asserts=0
        removed_asserts=$(echo "$diff_output" \
            | grep -cE '^\-.*\b(assert|expect|should|assertEqual|assertEquals|assertThat|assertTrue|assertFalse|toBe|toEqual|toMatch|toThrow)\b' 2>/dev/null || echo "0")
        added_asserts=$(echo "$diff_output" \
            | grep -cE '^\+.*\b(assert|expect|should|assertEqual|assertEquals|assertThat|assertTrue|assertFalse|toBe|toEqual|toMatch|toThrow)\b' 2>/dev/null || echo "0")

        removed_asserts="${removed_asserts//[!0-9]/}"
        added_asserts="${added_asserts//[!0-9]/}"
        : "${removed_asserts:=0}"
        : "${added_asserts:=0}"

        # Net assertion loss is suspicious
        if [[ "$removed_asserts" -gt "$added_asserts" ]]; then
            local net_loss=$((removed_asserts - added_asserts))
            _AUDIT_WEAKENING_FINDINGS="${_AUDIT_WEAKENING_FINDINGS}
WEAKENING: ${test_file} — net loss of ${net_loss} assertion(s) (removed ${removed_asserts}, added ${added_asserts})"
        fi

        # Detect specific→generic assertion pattern changes
        local broadened=""
        broadened=$(echo "$diff_output" \
            | grep -cE '^\+.*(assertTrue\s*\(|assertGreater|assertLess|toBeGreater|toBeLess|toBeTruthy|toBeFalsy)' 2>/dev/null || echo "0")
        broadened="${broadened//[!0-9]/}"
        : "${broadened:=0}"
        local specific_removed
        specific_removed=$(echo "$diff_output" \
            | grep -cE '^\-.*(assertEqual|assertEquals|toBe\(|toEqual\(|toStrictEqual)' 2>/dev/null || echo "0")
        specific_removed="${specific_removed//[!0-9]/}"
        : "${specific_removed:=0}"

        if [[ "$specific_removed" -gt 0 ]] && [[ "$broadened" -gt 0 ]]; then
            _AUDIT_WEAKENING_FINDINGS="${_AUDIT_WEAKENING_FINDINGS}
WEAKENING: ${test_file} — ${specific_removed} specific assertion(s) replaced with ${broadened} broader assertion(s)"
        fi

        # Detect removed test functions
        local removed_tests=0
        removed_tests=$(echo "$diff_output" \
            | grep -cE '^\-\s*(def test_|it\(|test\(|func Test|describe\()' 2>/dev/null || echo "0")
        removed_tests="${removed_tests//[!0-9]/}"
        : "${removed_tests:=0}"

        if [[ "$removed_tests" -gt 0 ]]; then
            _AUDIT_WEAKENING_FINDINGS="${_AUDIT_WEAKENING_FINDINGS}
WEAKENING: ${test_file} — ${removed_tests} test function(s) removed"
        fi
    done <<< "$_AUDIT_TEST_FILES"

    # Trim leading newline
    _AUDIT_WEAKENING_FINDINGS="${_AUDIT_WEAKENING_FINDINGS#$'\n'}"
    export _AUDIT_WEAKENING_FINDINGS
}
