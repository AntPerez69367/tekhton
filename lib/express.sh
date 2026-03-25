#!/usr/bin/env bash
set -euo pipefail
# =============================================================================
# express.sh — Express mode: zero-config pipeline execution
#
# Sourced by tekhton.sh — do not run directly.
# Depends on: common.sh (log, warn, success), detect.sh, detect_commands.sh,
#             config.sh (_parse_config_file, _clamp_config_value),
#             config_defaults.sh
# Provides: enter_express_mode(), persist_express_config()
# =============================================================================

# --- Express mode state flag ---
EXPRESS_MODE_ACTIVE=false
export EXPRESS_MODE_ACTIVE

# --- Detection (fast subset of M12 engine) -----------------------------------

# detect_express_config — Run fast language + command detection.
# Args: $1 = project directory
# Sets globals: _EXPRESS_PROJECT_NAME, _EXPRESS_LANGUAGES, _EXPRESS_COMMANDS
detect_express_config() {
    local proj_dir="$1"

    # Project name: from package manifest or directory basename
    _EXPRESS_PROJECT_NAME=$(_detect_express_project_name "$proj_dir")

    # Language detection (reuses M12 detect.sh — already fast)
    _EXPRESS_LANGUAGES=$(detect_languages "$proj_dir" 2>/dev/null || true)

    # Command detection (fast subset — no CI/CD, no workspace analysis)
    # detect_commands already handles modular detection; the heavy CI/CD
    # parts only run if detect_ci_config is loaded (which it is, but
    # the function is fast when no CI files exist)
    _EXPRESS_COMMANDS=$(detect_commands "$proj_dir" 2>/dev/null || true)
}

# _detect_express_project_name — Infer project name from manifest or dirname.
# Args: $1 = project directory
_detect_express_project_name() {
    local proj_dir="$1"
    local name=""

    # Try package.json "name" field
    if [[ -f "$proj_dir/package.json" ]]; then
        name=$(grep -oP '"name"\s*:\s*"\K[^"]+' "$proj_dir/package.json" 2>/dev/null | head -1 || true)
    fi

    # Try pyproject.toml "name" field
    if [[ -z "$name" ]] && [[ -f "$proj_dir/pyproject.toml" ]]; then
        name=$(grep -oP '^name\s*=\s*"\K[^"]+' "$proj_dir/pyproject.toml" 2>/dev/null | head -1 || true)
    fi

    # Try Cargo.toml "name" field
    if [[ -z "$name" ]] && [[ -f "$proj_dir/Cargo.toml" ]]; then
        name=$(grep -oP '^name\s*=\s*"\K[^"]+' "$proj_dir/Cargo.toml" 2>/dev/null | head -1 || true)
    fi

    # Try go.mod module name (last path segment)
    if [[ -z "$name" ]] && [[ -f "$proj_dir/go.mod" ]]; then
        local module
        module=$(head -1 "$proj_dir/go.mod" 2>/dev/null | awk '{print $2}' || true)
        if [[ -n "$module" ]]; then
            name="${module##*/}"
        fi
    fi

    # Fallback: directory basename
    if [[ -z "$name" ]]; then
        name=$(basename "$proj_dir")
    fi

    echo "$name"
}

# --- In-memory config generation ---------------------------------------------

# generate_express_config — Build pipeline config from detection results.
# Sets all pipeline variables as globals (same as load_config would).
generate_express_config() {
    # Essential config from detection
    declare -gx PROJECT_NAME="$_EXPRESS_PROJECT_NAME"
    declare -gx CLAUDE_STANDARD_MODEL="claude-sonnet-4-6"

    # Extract commands from detection output
    local test_cmd="" analyze_cmd="" build_cmd=""
    local cmd_type cmd
    while IFS='|' read -r cmd_type cmd _source _conf; do
        [[ -z "$cmd_type" ]] && continue
        case "$cmd_type" in
            test)    [[ -z "$test_cmd" ]] && test_cmd="$cmd" ;;
            analyze) [[ -z "$analyze_cmd" ]] && analyze_cmd="$cmd" ;;
            build)   [[ -z "$build_cmd" ]] && build_cmd="$cmd" ;;
        esac
    done <<< "$_EXPRESS_COMMANDS"

    # Conservative defaults for missing commands
    declare -gx TEST_CMD="${test_cmd:-true}"
    declare -gx ANALYZE_CMD="${analyze_cmd:-true}"
    declare -gx BUILD_CHECK_CMD="${build_cmd:-}"

    # Express mode uses conservative model settings
    declare -gx CLAUDE_CODER_MODEL="claude-sonnet-4-6"
    declare -gx CLAUDE_JR_CODER_MODEL="claude-sonnet-4-6"
    declare -gx CLAUDE_REVIEWER_MODEL="claude-sonnet-4-6"
    declare -gx CLAUDE_TESTER_MODEL="claude-sonnet-4-6"
    declare -gx CLAUDE_SCOUT_MODEL="claude-sonnet-4-6"

    # Conservative pipeline behavior
    declare -gx MAX_REVIEW_CYCLES="2"
    declare -gx SECURITY_AGENT_ENABLED="true"
    declare -gx INTAKE_AGENT_ENABLED="true"

    # Mark _CONF_KEYS_SET so validation passes
    # config.sh checks this for required keys
    _CONF_KEYS_SET=" PROJECT_NAME CLAUDE_STANDARD_MODEL ANALYZE_CMD "
    export _CONF_KEYS_SET

    # Apply all defaults (same as end of load_config)
    # shellcheck source=/dev/null
    source "${TEKHTON_HOME}/lib/config_defaults.sh"

    # Resolve relative paths to absolute (same as load_config)
    if [[ "$PIPELINE_STATE_FILE" != /* ]]; then
        PIPELINE_STATE_FILE="${PROJECT_DIR}/${PIPELINE_STATE_FILE}"
    fi
    if [[ "$LOG_DIR" != /* ]]; then
        LOG_DIR="${PROJECT_DIR}/${LOG_DIR}"
    fi
    if [[ "$MILESTONE_ARCHIVE_FILE" != /* ]]; then
        MILESTONE_ARCHIVE_FILE="${PROJECT_DIR}/${MILESTONE_ARCHIVE_FILE}"
    fi
    if [[ "${MILESTONE_DIR:-}" != /* ]] && [[ -n "${MILESTONE_DIR:-}" ]]; then
        MILESTONE_DIR="${PROJECT_DIR}/${MILESTONE_DIR}"
    fi
    if [[ "${CAUSAL_LOG_FILE:-}" != /* ]] && [[ -n "${CAUSAL_LOG_FILE:-}" ]]; then
        CAUSAL_LOG_FILE="${PROJECT_DIR}/${CAUSAL_LOG_FILE}"
    fi
}

# --- Role file fallback ------------------------------------------------------

# resolve_role_file — Returns the project role file if it exists, otherwise
# falls back to the built-in template in TEKHTON_HOME/templates/.
# Args: $1 = role file path (relative to PROJECT_DIR), $2 = template basename
# Returns: resolved path (prints to stdout)
resolve_role_file() {
    local role_file="$1"
    local template_name="$2"
    local full_path

    # Resolve relative path
    if [[ "$role_file" != /* ]]; then
        full_path="${PROJECT_DIR}/${role_file}"
    else
        full_path="$role_file"
    fi

    if [[ -f "$full_path" ]]; then
        echo "$role_file"
    else
        local fallback="${TEKHTON_HOME}/templates/${template_name}"
        if [[ -f "$fallback" ]]; then
            log "Using built-in role template for ${template_name%.md} (no project-specific role file found)." >&2
            echo "$fallback"
        else
            # Last resort: return original (agent will get a read error)
            echo "$role_file"
        fi
    fi
}

# apply_role_file_fallbacks — Check all role file variables and apply fallback
# to built-in templates when project files don't exist.
apply_role_file_fallbacks() {
    CODER_ROLE_FILE=$(resolve_role_file "$CODER_ROLE_FILE" "coder.md")
    REVIEWER_ROLE_FILE=$(resolve_role_file "$REVIEWER_ROLE_FILE" "reviewer.md")
    TESTER_ROLE_FILE=$(resolve_role_file "$TESTER_ROLE_FILE" "tester.md")
    JR_CODER_ROLE_FILE=$(resolve_role_file "$JR_CODER_ROLE_FILE" "jr-coder.md")
    ARCHITECT_ROLE_FILE=$(resolve_role_file "$ARCHITECT_ROLE_FILE" "architect.md")
    SECURITY_ROLE_FILE=$(resolve_role_file "${SECURITY_ROLE_FILE:-.claude/agents/security.md}" "security.md")
    INTAKE_ROLE_FILE=$(resolve_role_file "${INTAKE_ROLE_FILE:-.claude/agents/intake.md}" "intake.md")
}

# --- Express mode entry point ------------------------------------------------

# enter_express_mode — Called from tekhton.sh when no pipeline.conf exists.
# Runs detection, generates in-memory config, returns control to normal pipeline.
# Args: $1 = project directory, $2 = task
enter_express_mode() {
    local proj_dir="$1"

    EXPRESS_MODE_ACTIVE=true
    export EXPRESS_MODE_ACTIVE

    # Print express mode banner
    echo
    echo -e "\033[1;36m╔══════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;36m║  EXPRESS MODE — Auto-detected configuration                 ║\033[0m"
    echo -e "\033[1;36m║  For full configuration, run: tekhton --init                 ║\033[0m"
    echo -e "\033[1;36m╚══════════════════════════════════════════════════════════════╝\033[0m"
    echo

    # Run fast detection
    log "Detecting project configuration..."
    detect_express_config "$proj_dir"

    # Show detection results
    if [[ -n "$_EXPRESS_LANGUAGES" ]]; then
        local primary_lang
        primary_lang=$(echo "$_EXPRESS_LANGUAGES" | head -1 | cut -d'|' -f1)
        log "  Language: ${primary_lang}"
    else
        log "  Language: unknown (using conservative defaults)"
    fi

    local _test_found="" _analyze_found="" _build_found=""
    local _ctype _ccmd
    while IFS='|' read -r _ctype _ccmd _csrc _cconf; do
        [[ -z "$_ctype" ]] && continue
        case "$_ctype" in
            test)    _test_found="$_ccmd" ;;
            analyze) _analyze_found="$_ccmd" ;;
            build)   _build_found="$_ccmd" ;;
        esac
    done <<< "$_EXPRESS_COMMANDS"
    [[ -n "$_test_found" ]] && log "  Test cmd: ${_test_found}"
    [[ -n "$_analyze_found" ]] && log "  Analyze cmd: ${_analyze_found}"
    [[ -n "$_build_found" ]] && log "  Build cmd: ${_build_found}"
    echo

    # Generate in-memory config
    generate_express_config

    # Create .claude directory if needed (for logs, state)
    mkdir -p "${proj_dir}/.claude/logs" 2>/dev/null || true

    # Apply role file fallbacks
    apply_role_file_fallbacks

    # Create a minimal PROJECT_RULES_FILE if it doesn't exist
    if [[ ! -f "${proj_dir}/${PROJECT_RULES_FILE}" ]]; then
        log "Creating minimal ${PROJECT_RULES_FILE} for express mode..."
        cat > "${proj_dir}/${PROJECT_RULES_FILE}" << EXPRESSEOF
# ${PROJECT_NAME} — Project Rules (Express Mode)

This file was auto-generated by Tekhton Express Mode.
Run \`tekhton --init\` for full project configuration with planning interview.

## Project
- Name: ${PROJECT_NAME}
EXPRESSEOF
    fi
}

# --- Config persistence (called from finalize.sh on success) -----------------

# persist_express_config — Write detected config to .claude/pipeline.conf.
# Args: $1 = project directory
persist_express_config() {
    local proj_dir="$1"
    local conf_path="${proj_dir}/.claude/pipeline.conf"

    # Never overwrite an existing pipeline.conf
    if [[ -f "$conf_path" ]]; then
        return 0
    fi

    mkdir -p "${proj_dir}/.claude" 2>/dev/null || true

    # Build config from template with detected values
    local template="${TEKHTON_HOME}/templates/express_pipeline.conf"
    if [[ ! -f "$template" ]]; then
        warn "Express config template not found — writing inline config."
        _write_inline_express_config "$conf_path"
        return 0
    fi

    # Read template and substitute detected values
    local content
    content=$(cat "$template")

    # Substitute template variables
    content="${content//\{\{PROJECT_NAME\}\}/${PROJECT_NAME}}"
    content="${content//\{\{TEST_CMD\}\}/${TEST_CMD}}"
    content="${content//\{\{ANALYZE_CMD\}\}/${ANALYZE_CMD}}"
    content="${content//\{\{BUILD_CHECK_CMD\}\}/${BUILD_CHECK_CMD:-}}"
    content="${content//\{\{CLAUDE_STANDARD_MODEL\}\}/${CLAUDE_STANDARD_MODEL}}"

    # Write atomically (tmpfile + mv)
    local tmpfile
    tmpfile=$(mktemp "${proj_dir}/.claude/express_conf_XXXXXX")
    echo "$content" > "$tmpfile"
    mv "$tmpfile" "$conf_path"

    log "Express config saved to ${conf_path}"
}

# _write_inline_express_config — Fallback: write config without template.
_write_inline_express_config() {
    local conf_path="$1"
    cat > "$conf_path" << CONFEOF
# Auto-detected by Tekhton Express Mode.
# Run 'tekhton --init' for full configuration with planning interview.

PROJECT_NAME="${PROJECT_NAME}"
CLAUDE_STANDARD_MODEL="${CLAUDE_STANDARD_MODEL}"
TEST_CMD="${TEST_CMD}"
ANALYZE_CMD="${ANALYZE_CMD}"
BUILD_CHECK_CMD="${BUILD_CHECK_CMD:-}"
CONFEOF
}

# persist_express_roles — Copy built-in role templates to project.
# Args: $1 = project directory
persist_express_roles() {
    local proj_dir="$1"
    local agents_dir="${proj_dir}/.claude/agents"

    mkdir -p "$agents_dir" 2>/dev/null || true

    local template_name
    for template_name in coder.md reviewer.md tester.md jr-coder.md architect.md security.md intake.md; do
        local src="${TEKHTON_HOME}/templates/${template_name}"
        local dst="${agents_dir}/${template_name}"
        if [[ -f "$src" ]] && [[ ! -f "$dst" ]]; then
            cp "$src" "$dst"
        fi
    done
}
