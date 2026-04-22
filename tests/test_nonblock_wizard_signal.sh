#!/usr/bin/env bash
# Tests for _WIZARD_VENV_CREATED signal (non-blocking note 3)
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TEKHTON_HOME="$(cd "$SCRIPT_DIR/.." && pwd)"

source "${TEKHTON_HOME}/lib/common.sh"
source "${TEKHTON_HOME}/lib/init_wizard.sh"

# Test signal is exported when venv setup runs
_test_signal_exported() {
    local tmpdir
    tmpdir=$(mktemp -d)
    trap "rm -rf '$tmpdir'" EXIT

    local project_dir="$tmpdir/project"
    local conf_dir="$project_dir/.claude"
    mkdir -p "$conf_dir/logs"

    # Create dummy setup scripts
    mkdir -p "$tmpdir/tools"
    cat > "$tmpdir/tools/setup_indexer.sh" <<'SCRIPT'
#!/bin/bash
exit 0
SCRIPT
    chmod +x "$tmpdir/tools/setup_indexer.sh"

    # Simulate wizard enabling venv setup
    export _WIZARD_NEEDS_VENV="true"
    export _WIZARD_SERENA_ENABLED="false"
    export REPO_MAP_VENV_DIR="$project_dir/.claude/indexer-venv"

    # Before running, signal should be unset
    unset _WIZARD_VENV_CREATED || true

    # Run setup
    _run_wizard_venv_setup "$project_dir" "$tmpdir" "$conf_dir"

    # Signal should now be set to "true"
    if [[ "${_WIZARD_VENV_CREATED:-}" == "true" ]]; then
        echo "PASS: _WIZARD_VENV_CREATED exported as 'true'"
        return 0
    else
        echo "FAIL: _WIZARD_VENV_CREATED not set to 'true' (got: ${_WIZARD_VENV_CREATED:-unset})"
        return 1
    fi
}

# Test signal is unset when venv setup doesn't run (early return)
_test_signal_unset_when_skipped() {
    # Reset state
    _wizard_reset_state

    # _WIZARD_NEEDS_VENV is not set, so _run_wizard_venv_setup returns early
    # Signal should remain unset
    local tmpdir
    tmpdir=$(mktemp -d)
    trap "rm -rf '$tmpdir'" EXIT

    _run_wizard_venv_setup "$tmpdir/project" "$tmpdir" "$tmpdir/.claude"

    if [[ "${_WIZARD_VENV_CREATED:-}" == "" ]]; then
        echo "PASS: _WIZARD_VENV_CREATED remains unset when setup is skipped"
        return 0
    else
        echo "FAIL: _WIZARD_VENV_CREATED was set when it should be unset"
        return 1
    fi
}

# Test signal is reset on repeated calls
_test_signal_reset() {
    local tmpdir
    tmpdir=$(mktemp -d)
    trap "rm -rf '$tmpdir'" EXIT

    local project_dir="$tmpdir/project"
    local conf_dir="$project_dir/.claude"
    mkdir -p "$conf_dir/logs"

    mkdir -p "$tmpdir/tools"
    cat > "$tmpdir/tools/setup_indexer.sh" <<'SCRIPT'
#!/bin/bash
exit 0
SCRIPT
    chmod +x "$tmpdir/tools/setup_indexer.sh"

    # Run once
    export _WIZARD_NEEDS_VENV="true"
    _run_wizard_venv_setup "$project_dir" "$tmpdir" "$conf_dir"
    if [[ "${_WIZARD_VENV_CREATED:-}" != "true" ]]; then
        echo "FAIL: First signal export failed"
        return 1
    fi

    # Reset state (simulating a new wizard invocation)
    _wizard_reset_state
    if [[ "${_WIZARD_VENV_CREATED:-}" == "" ]]; then
        echo "PASS: _wizard_reset_state clears _WIZARD_VENV_CREATED"
        return 0
    else
        echo "FAIL: _wizard_reset_state did not clear signal"
        return 1
    fi
}

_test_signal_exported || exit 1
_test_signal_unset_when_skipped || exit 1
_test_signal_reset || exit 1

echo "All wizard signal tests passed"
exit 0
