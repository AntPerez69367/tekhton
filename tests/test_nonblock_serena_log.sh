#!/usr/bin/env bash
# Tests for Serena log separation (non-blocking note 1)
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TEKHTON_HOME="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source dependencies
source "${TEKHTON_HOME}/lib/common.sh"
source "${TEKHTON_HOME}/lib/init_wizard.sh"

# Test fixture
_test_serena_log_separate() {
    local tmpdir
    tmpdir=$(mktemp -d)
    trap "rm -rf '$tmpdir'" EXIT

    local project_dir="$tmpdir/project"
    local tekhton_home="$TEKHTON_HOME"
    local conf_dir="$project_dir/.claude"
    mkdir -p "$conf_dir/logs"

    # Create dummy setup scripts that succeed
    mkdir -p "$tmpdir/tools"
    cat > "$tmpdir/tools/setup_indexer.sh" <<'SCRIPT'
#!/bin/bash
echo "Indexer setup ran"
exit 0
SCRIPT
    chmod +x "$tmpdir/tools/setup_indexer.sh"

    cat > "$tmpdir/tools/setup_serena.sh" <<'SCRIPT'
#!/bin/bash
echo "Serena setup ran"
exit 0
SCRIPT
    chmod +x "$tmpdir/tools/setup_serena.sh"

    # Simulate wizard enabling both features
    export _WIZARD_NEEDS_VENV="true"
    export _WIZARD_SERENA_ENABLED="true"
    export REPO_MAP_VENV_DIR="$project_dir/.claude/indexer-venv"
    export SERENA_PATH="$project_dir/.claude/serena"

    # Run the setup (VERBOSE_OUTPUT must be false so logs are captured)
    VERBOSE_OUTPUT="false" _run_wizard_venv_setup "$project_dir" "$tmpdir" "$conf_dir"

    # Verify separate log files were created
    local indexer_log="$conf_dir/logs/indexer_setup.log"
    local serena_log="$conf_dir/logs/serena_setup.log"

    if [[ ! -f "$indexer_log" ]]; then
        echo "FAIL: indexer_setup.log not created at $indexer_log"
        return 1
    fi

    if [[ ! -f "$serena_log" ]]; then
        echo "FAIL: serena_setup.log not created at $serena_log"
        return 1
    fi

    # Verify they have different content
    if ! grep -q "Indexer setup ran" "$indexer_log"; then
        echo "FAIL: indexer_setup.log missing expected output"
        return 1
    fi

    if ! grep -q "Serena setup ran" "$serena_log"; then
        echo "FAIL: serena_setup.log missing expected output"
        return 1
    fi

    # Verify Serena output is NOT in indexer log
    if grep -q "Serena setup" "$indexer_log"; then
        echo "FAIL: Serena output found in indexer_setup.log (logs should be separate)"
        return 1
    fi

    echo "PASS: Serena logs are separate from indexer logs"
    return 0
}

_test_serena_log_separate
exit $?
