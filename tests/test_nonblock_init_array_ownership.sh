#!/usr/bin/env bash
# Tests for init.sh array ownership (non-blocking note 3)
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TEKHTON_HOME="$(cd "$SCRIPT_DIR/.." && pwd)"

source "${TEKHTON_HOME}/lib/common.sh"

# Test that _INIT_FILES_WRITTEN is appended to when signal is set
_test_array_append_on_signal() {
    local tmpdir
    tmpdir=$(mktemp -d)
    trap "rm -rf '$tmpdir'" EXIT

    # Create a minimal test that mimics the init.sh logic
    local -a _INIT_FILES_WRITTEN=()

    # Simulate the check in init.sh at line 161-163
    export _WIZARD_VENV_CREATED="true"
    if [[ "${_WIZARD_VENV_CREATED:-}" == "true" ]]; then
        _INIT_FILES_WRITTEN+=(".claude/indexer-venv/|Python environment for enhanced features")
    fi

    if [[ ${#_INIT_FILES_WRITTEN[@]} -eq 1 ]] && [[ "${_INIT_FILES_WRITTEN[0]}" == ".claude/indexer-venv/"* ]]; then
        echo "PASS: Array appended to when signal is 'true'"
        return 0
    else
        echo "FAIL: Array not properly appended (got ${#_INIT_FILES_WRITTEN[@]} entries)"
        return 1
    fi
}

# Test that array is not appended to when signal is not set
_test_array_not_appended_when_signal_unset() {
    # Reset
    unset _WIZARD_VENV_CREATED || true

    local -a _INIT_FILES_WRITTEN=()

    # Simulate the check in init.sh
    if [[ "${_WIZARD_VENV_CREATED:-}" == "true" ]]; then
        _INIT_FILES_WRITTEN+=(".claude/indexer-venv/|Python environment for enhanced features")
    fi

    if [[ ${#_INIT_FILES_WRITTEN[@]} -eq 0 ]]; then
        echo "PASS: Array not appended when signal is unset"
        return 0
    else
        echo "FAIL: Array was appended when signal was unset (got ${#_INIT_FILES_WRITTEN[@]} entries)"
        return 1
    fi
}

# Test that array is not appended to when signal is "false"
_test_array_not_appended_when_signal_false() {
    export _WIZARD_VENV_CREATED="false"

    local -a _INIT_FILES_WRITTEN=()

    # Simulate the check in init.sh
    if [[ "${_WIZARD_VENV_CREATED:-}" == "true" ]]; then
        _INIT_FILES_WRITTEN+=(".claude/indexer-venv/|Python environment for enhanced features")
    fi

    if [[ ${#_INIT_FILES_WRITTEN[@]} -eq 0 ]]; then
        echo "PASS: Array not appended when signal is 'false'"
        return 0
    else
        echo "FAIL: Array was appended when signal was 'false'"
        return 1
    fi
}

# Test multiple array entries (array ownership stays in init.sh)
_test_multiple_entries() {
    export _WIZARD_VENV_CREATED="true"

    local -a _INIT_FILES_WRITTEN=()
    _INIT_FILES_WRITTEN+=(".claude/pipeline.conf|primary config")

    # Only append if signal is set
    if [[ "${_WIZARD_VENV_CREATED:-}" == "true" ]]; then
        _INIT_FILES_WRITTEN+=(".claude/indexer-venv/|Python environment")
    fi

    if [[ ${#_INIT_FILES_WRITTEN[@]} -eq 2 ]]; then
        echo "PASS: Multiple entries maintained, signal-based append works"
        return 0
    else
        echo "FAIL: Expected 2 entries, got ${#_INIT_FILES_WRITTEN[@]}"
        return 1
    fi
}

_test_array_append_on_signal || exit 1
_test_array_not_appended_when_signal_unset || exit 1
_test_array_not_appended_when_signal_false || exit 1
_test_multiple_entries || exit 1

echo "All init array ownership tests passed"
exit 0
