#!/usr/bin/env bash
# Test: review.sh senior coder rework uses EFFECTIVE_CODER_MAX_TURNS (M91 Note 5)
set -euo pipefail

TEKHTON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$(mktemp -d)"
trap "rm -rf $PROJECT_DIR" EXIT

# Source required libraries
source "$TEKHTON_DIR/lib/common.sh"

# Test: Check that review.sh has correct escalation variable on senior coder rework line
test_review_senior_coder_escalation() {
    local review_file="$TEKHTON_DIR/stages/review.sh"

    # Senior coder rework should use EFFECTIVE_CODER_MAX_TURNS, not bare CODER_MAX_TURNS
    if grep -q '"${EFFECTIVE_CODER_MAX_TURNS:-' "$review_file"; then
        return 0
    else
        echo "FAIL: Senior coder rework should use \${EFFECTIVE_CODER_MAX_TURNS:-\$CODER_MAX_TURNS}"
        return 1
    fi
}

# Test: Check that jr coder rework sites also use correct escalation (consistency check)
test_review_jr_coder_escalation() {
    local review_file="$TEKHTON_DIR/stages/review.sh"

    # Count how many jr coder invocations use the correct escalation variable
    local correct_count
    correct_count=$(grep -c '"${EFFECTIVE_JR_CODER_MAX_TURNS:-' "$review_file" || true)

    # Count how many jr coder invocations exist (look for "Jr Coder" in run_agent lines)
    local total_jr_count
    total_jr_count=$(grep -c '"Jr Coder' "$review_file" || true)

    # They should match
    if [[ $correct_count -eq $total_jr_count ]]; then
        return 0
    else
        echo "FAIL: Found $total_jr_count Jr Coder invocations but only $correct_count use correct escalation"
        return 1
    fi
}

# Test: Verify both senior and jr coder use same escalation pattern
test_escalation_pattern_consistency() {
    local review_file="$TEKHTON_DIR/stages/review.sh"

    # Both should use the pattern: "${EFFECTIVE_*_MAX_TURNS:-$*_MAX_TURNS}"
    local senior_has_escalation
    senior_has_escalation=$(grep -c '"${EFFECTIVE_CODER_MAX_TURNS:-' "$review_file" || true)

    local jr_has_escalation
    jr_has_escalation=$(grep -c '"${EFFECTIVE_JR_CODER_MAX_TURNS:-' "$review_file" || true)

    # Both should be using escalation (at least 1 each)
    if [[ $senior_has_escalation -gt 0 ]] && [[ $jr_has_escalation -gt 0 ]]; then
        return 0
    else
        echo "FAIL: Senior escalation count: $senior_has_escalation, Jr escalation count: $jr_has_escalation"
        return 1
    fi
}

# Run all tests
if test_review_senior_coder_escalation && \
   test_review_jr_coder_escalation && \
   test_escalation_pattern_consistency; then
    echo "PASS"
    exit 0
else
    echo "FAIL"
    exit 1
fi
