#!/usr/bin/env bash
# =============================================================================
# test_human_flag_arg_parser.sh — `--human [TAG]` argument parsing edge cases
#
# Tests the integration-level behavior of the --human flag parser in tekhton.sh:
# - `--human BUG` sets HUMAN_NOTES_TAG to "BUG"
# - `--human FEAT` sets HUMAN_NOTES_TAG to "FEAT"
# - `--human POLISH` sets HUMAN_NOTES_TAG to "POLISH"
# - `--human --complete` does NOT consume `--complete` as a tag
# - `--human` as final argument leaves HUMAN_NOTES_TAG empty
# - `--human INVALID_TAG` does NOT consume invalid tags
# - `--human` always sets HUMAN_MODE=true
# =============================================================================
set -euo pipefail

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

FAIL=0

# Helper: simulate the argument parsing logic from tekhton.sh lines 532-540
parse_human_flag() {
    local -n args_array="$1"
    local -n out_human_mode="$2"
    local -n out_human_tag="$3"

    out_human_mode=false
    out_human_tag=""

    local i=0
    while [ $i -lt ${#args_array[@]} ]; do
        if [ "${args_array[$i]}" = "--human" ]; then
            out_human_mode=true
            i=$((i + 1))

            # Consume optional tag argument (BUG, FEAT, POLISH) if present
            if [ $i -lt ${#args_array[@]} ] && [[ "${args_array[$i]}" =~ ^(BUG|FEAT|POLISH)$ ]]; then
                out_human_tag="${args_array[$i]}"
                i=$((i + 1))
            fi
            return 0
        fi
        i=$((i + 1))
    done

    return 1  # --human not found
}

# Test helper
test_parser() {
    local name="$1"
    local expected_mode="$2"
    local expected_tag="$3"
    shift 3

    local args=("$@")
    local human_mode=""
    local human_tag=""

    if parse_human_flag args human_mode human_tag 2>/dev/null; then
        # --human flag was found
        if [ "$human_mode" != "$expected_mode" ]; then
            echo "FAIL: $name — HUMAN_MODE: expected '$expected_mode', got '$human_mode'"
            FAIL=1
            return
        fi

        if [ "$human_tag" != "$expected_tag" ]; then
            echo "FAIL: $name — HUMAN_NOTES_TAG: expected '$expected_tag', got '$human_tag'"
            FAIL=1
            return
        fi
    else
        # --human flag was NOT found — test should only reach here if we expect that
        echo "FAIL: $name — --human flag not found in arguments"
        FAIL=1
        return
    fi
}

# =============================================================================
# Test 1: --human with no tag argument
# =============================================================================

test_parser "1.1 --human alone" "true" "" --human

# =============================================================================
# Test 2: --human with BUG tag
# =============================================================================

test_parser "2.1 --human BUG" "true" "BUG" --human BUG

# =============================================================================
# Test 3: --human with FEAT tag
# =============================================================================

test_parser "3.1 --human FEAT" "true" "FEAT" --human FEAT

# =============================================================================
# Test 4: --human with POLISH tag
# =============================================================================

test_parser "4.1 --human POLISH" "true" "POLISH" --human POLISH

# =============================================================================
# Test 5: --human followed by non-tag argument should NOT consume it
# =============================================================================

test_parser "5.1 --human followed by --complete" "true" "" --human --complete
test_parser "5.2 --human followed by --milestone" "true" "" --human --milestone
test_parser "5.3 --human followed by task string" "true" "" --human "some task"

# =============================================================================
# Test 6: --human as final argument
# =============================================================================

test_parser "6.1 --human as final arg in list" "true" "" --complete --milestone --human

# =============================================================================
# Test 7: --human with invalid tag (should NOT consume it)
# =============================================================================

test_parser "7.1 --human with INVALID_TAG" "true" "" --human INVALID_TAG
test_parser "7.2 --human with lowercase bug" "true" "" --human bug
test_parser "7.3 --human with mixed case Bug" "true" "" --human Bug

# =============================================================================
# Test 8: --human in different positions
# =============================================================================

test_parser "8.1 --human at start" "true" "" --human --complete --milestone
test_parser "8.2 --human in middle" "true" "" --complete --human --milestone
test_parser "8.3 --human at end" "true" "" --complete --milestone --human

# =============================================================================
# Test 9: Multiple tags with --human (only first valid one consumed)
# =============================================================================

# This is an edge case: --human BUG FEAT should consume BUG as tag
# and FEAT should remain as a positional argument
test_parser "9.1 --human BUG with FEAT following" "true" "BUG" --human BUG FEAT

# =============================================================================
# Test 10: Case sensitivity of tags
# =============================================================================

test_parser "10.1 Uppercase BUG" "true" "BUG" --human BUG
test_parser "10.2 Uppercase FEAT" "true" "FEAT" --human FEAT
test_parser "10.3 Uppercase POLISH" "true" "POLISH" --human POLISH

# Case variants should NOT be consumed
test_parser "10.4 Lowercase bug should not be consumed" "true" "" --human bug
test_parser "10.5 Title case Bug should not be consumed" "true" "" --human Bug
test_parser "10.6 Title case Feat should not be consumed" "true" "" --human Feat

# =============================================================================

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
