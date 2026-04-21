#!/usr/bin/env bash
# Tests for stage label consistency (non-blocking note 6)
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TEKHTON_HOME="$(cd "$SCRIPT_DIR/.." && pwd)"

source "${TEKHTON_HOME}/lib/common.sh"
source "${TEKHTON_HOME}/lib/pipeline_order.sh"

# Test that get_display_stage_order uses get_stage_display_label
_test_label_consistency() {
    # Standard pipeline
    export PIPELINE_ORDER="standard"
    export INTAKE_AGENT_ENABLED="true"
    export SECURITY_AGENT_ENABLED="true"
    export SKIP_SECURITY="false"
    export SKIP_DOCS="false"
    export DOCS_AGENT_ENABLED="false"

    local display_order
    display_order=$(get_display_stage_order)

    # Parse the display order and verify each label is consistent
    local stage
    for stage in intake coder security review test_verify wrap-up; do
        local expected_label
        expected_label=$(get_stage_display_label "$stage")

        if [[ "$display_order" == *"$expected_label"* ]]; then
            # Label is in display order, good
            :
        else
            # Only check stages that should be in standard order
            case "$stage" in
                intake|coder|security|review|wrap-up)
                    echo "FAIL: Expected label '$expected_label' in display order: $display_order"
                    return 1
                    ;;
            esac
        fi
    done

    echo "PASS: Label consistency check passed for standard order"
    return 0
}

# Test fallback label generation (underscore to hyphen)
_test_fallback_label_generation() {
    local fallback_stage="custom_stage"
    local label
    label=$(get_stage_display_label "$fallback_stage")

    if [[ "$label" == "custom-stage" ]]; then
        echo "PASS: Fallback label generation works (underscores to hyphens)"
        return 0
    else
        echo "FAIL: Fallback label generation failed (expected 'custom-stage', got '$label')"
        return 1
    fi
}

# Test explicit mappings
_test_explicit_mappings() {
    # Test that each explicit mapping is correct
    local mappings=(
        "intake:intake"
        "scout:scout"
        "coder:coder"
        "test_write:tester-write"
        "test_verify:tester"
        "security:security"
        "review:review"
        "docs:docs"
        "rework:rework"
        "wrap_up:wrap-up"
    )

    for mapping in "${mappings[@]}"; do
        local stage="${mapping%:*}"
        local expected="${mapping#*:}"
        local actual
        actual=$(get_stage_display_label "$stage")

        if [[ "$actual" != "$expected" ]]; then
            echo "FAIL: Expected '$stage' → '$expected', got '$actual'"
            return 1
        fi
    done

    echo "PASS: All explicit stage mappings are correct"
    return 0
}

# Test that new stages (only in fallback) work consistently
_test_new_stage_consistency() {
    # Simulate a new stage that would only exist in pipeline order
    # (not yet in explicit mappings)
    local new_stage="experimental_feature"

    local label1 label2
    label1=$(get_stage_display_label "$new_stage")
    label2=$(get_stage_display_label "$new_stage")

    if [[ "$label1" == "$label2" ]] && [[ "$label1" == "experimental-feature" ]]; then
        echo "PASS: New stages generate consistent labels via fallback"
        return 0
    else
        echo "FAIL: New stage inconsistency (got '$label1' and '$label2')"
        return 1
    fi
}

# Test that get_display_stage_order filters correctly
_test_display_order_filtering() {
    export PIPELINE_ORDER="standard"
    export INTAKE_AGENT_ENABLED="false"
    export SECURITY_AGENT_ENABLED="true"
    export SKIP_SECURITY="false"
    export DOCS_AGENT_ENABLED="false"

    local display_order
    display_order=$(get_display_stage_order)

    # When INTAKE_AGENT_ENABLED=false, "intake" should not be in the display
    if [[ "$display_order" != "intake"* ]]; then
        echo "PASS: Intake filtering works when INTAKE_AGENT_ENABLED=false"
        return 0
    else
        echo "FAIL: Intake appears in display order when disabled"
        return 1
    fi
}

# Test security filtering
_test_security_filtering() {
    export PIPELINE_ORDER="standard"
    export INTAKE_AGENT_ENABLED="true"
    export SECURITY_AGENT_ENABLED="false"
    export SKIP_SECURITY="false"
    export DOCS_AGENT_ENABLED="false"

    local display_order
    display_order=$(get_display_stage_order)

    # When SECURITY_AGENT_ENABLED=false, "security" should not be in the display
    if [[ "$display_order" != *"security"* ]]; then
        echo "PASS: Security filtering works when SECURITY_AGENT_ENABLED=false"
        return 0
    else
        echo "FAIL: Security appears in display order when disabled"
        return 1
    fi
}

_test_label_consistency || exit 1
_test_fallback_label_generation || exit 1
_test_explicit_mappings || exit 1
_test_new_stage_consistency || exit 1
_test_display_order_filtering || exit 1
_test_security_filtering || exit 1

echo "All stage label consistency tests passed"
exit 0
