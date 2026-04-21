#!/usr/bin/env bash
# Tests for exit code propagation in _wizard_run_setup_script (non-blocking note 2)
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TEKHTON_HOME="$(cd "$SCRIPT_DIR/.." && pwd)"

source "${TEKHTON_HOME}/lib/common.sh"
source "${TEKHTON_HOME}/lib/init_wizard.sh"

# Test successful script exit code
_test_return_success() {
    local tmpdir
    tmpdir=$(mktemp -d)
    trap "rm -rf '$tmpdir'" EXIT

    mkdir -p "$tmpdir/logs"

    # Create script that exits with 0
    cat > "$tmpdir/success.sh" <<'SCRIPT'
#!/bin/bash
echo "Success"
exit 0
SCRIPT
    chmod +x "$tmpdir/success.sh"

    if _wizard_run_setup_script "Test success" "$tmpdir/success.sh" "$tmpdir/logs/test.log"; then
        echo "PASS: Success exit code propagated correctly"
        return 0
    else
        echo "FAIL: _wizard_run_setup_script returned non-zero on successful script"
        return 1
    fi
}

# Test failed script exit code
_test_return_failure() {
    local tmpdir
    tmpdir=$(mktemp -d)
    trap "rm -rf '$tmpdir'" EXIT

    mkdir -p "$tmpdir/logs"

    # Create script that exits with non-zero
    cat > "$tmpdir/failure.sh" <<'SCRIPT'
#!/bin/bash
echo "Failure"
exit 42
SCRIPT
    chmod +x "$tmpdir/failure.sh"

    if _wizard_run_setup_script "Test failure" "$tmpdir/failure.sh" "$tmpdir/logs/test.log"; then
        echo "FAIL: _wizard_run_setup_script returned 0 on failing script"
        return 1
    else
        local exit_code=$?
        if [[ "$exit_code" -eq 1 ]]; then
            echo "PASS: Failure exit code propagated (converted to 1)"
            return 0
        else
            echo "FAIL: Unexpected exit code: $exit_code (expected 1)"
            return 1
        fi
    fi
}

# Test with VERBOSE_OUTPUT enabled (bare return)
_test_verbose_return_success() {
    local tmpdir
    tmpdir=$(mktemp -d)
    trap "rm -rf '$tmpdir'" EXIT

    # Create script that exits with 0
    cat > "$tmpdir/verbose_success.sh" <<'SCRIPT'
#!/bin/bash
echo "Verbose success"
exit 0
SCRIPT
    chmod +x "$tmpdir/verbose_success.sh"

    export VERBOSE_OUTPUT="true"
    if _wizard_run_setup_script "Test verbose" "$tmpdir/verbose_success.sh" "/dev/null"; then
        echo "PASS: Verbose mode propagates success exit code"
        unset VERBOSE_OUTPUT
        return 0
    else
        echo "FAIL: Verbose mode failed to propagate success"
        unset VERBOSE_OUTPUT
        return 1
    fi
}

# Test with VERBOSE_OUTPUT enabled (failure case)
_test_verbose_return_failure() {
    local tmpdir
    tmpdir=$(mktemp -d)
    trap "rm -rf '$tmpdir'" EXIT

    # Create script that exits with non-zero
    cat > "$tmpdir/verbose_failure.sh" <<'SCRIPT'
#!/bin/bash
echo "Verbose failure"
exit 127
SCRIPT
    chmod +x "$tmpdir/verbose_failure.sh"

    export VERBOSE_OUTPUT="true"
    if _wizard_run_setup_script "Test verbose failure" "$tmpdir/verbose_failure.sh" "/dev/null"; then
        echo "FAIL: Verbose mode did not propagate failure"
        unset VERBOSE_OUTPUT
        return 1
    else
        echo "PASS: Verbose mode propagates failure exit code"
        unset VERBOSE_OUTPUT
        return 0
    fi
}

_test_return_success || exit 1
_test_return_failure || exit 1
_test_verbose_return_success || exit 1
_test_verbose_return_failure || exit 1

echo "All return propagation tests passed"
exit 0
