#!/usr/bin/env bash
set -euo pipefail
# =============================================================================
# init_report_banner.sh — Three-part post-init terminal banner (Milestone 81)
#
# Provides: emit_init_summary, _init_pick_recommendation,
#           _init_render_files_written, _emit_summary_command
#
# Sourced by init_report.sh — do not run directly.
# Depends on: common.sh (BOLD, GREEN, YELLOW, CYAN, NC, RED)
# =============================================================================

# Ensure _INIT_FILES_WRITTEN exists — init.sh declares it, but tests and
# standalone sourcing may skip init.sh.
if ! declare -p _INIT_FILES_WRITTEN &>/dev/null; then
    _INIT_FILES_WRITTEN=()
fi

# --- Recommendation heuristic ------------------------------------------------

# _init_pick_recommendation — Pure function: returns one recommended command.
# Args: $1=file_count, $2=has_manifest(true/false), $3=has_pending(true/false)
# Output: CMD|DESCRIPTION|ALT1|ALT2
_init_pick_recommendation() {
    local file_count="$1"
    local has_manifest="$2"
    local has_pending="$3"

    if [[ "$has_pending" == "true" ]]; then
        echo "tekhton|run next pending milestone|--draft-milestones|--plan"
    elif [[ "$file_count" -gt 50 ]]; then
        echo "tekhton --plan-from-index|synthesize plan from detected structure|--draft-milestones|--plan"
    elif [[ "$file_count" -gt 0 ]]; then
        echo "tekhton --plan \"goal\"|interview-style plan|--draft-milestones|"
    else
        echo "tekhton --plan \"goal\"|interview-style plan (greenfield)||"
    fi
}

# --- File list renderer -------------------------------------------------------

# _init_render_files_written — Renders the "What Tekhton wrote" section.
# Reads global _INIT_FILES_WRITTEN array. Truncates to 8 entries.
_init_render_files_written() {
    local bullet="$1"
    local total=${#_INIT_FILES_WRITTEN[@]}
    local max_show=8
    local shown=0

    local entry path desc
    for entry in "${_INIT_FILES_WRITTEN[@]}"; do
        [[ "$shown" -ge "$max_show" ]] && break
        path="${entry%%|*}"
        desc="${entry#*|}"
        printf "    %s %-36s (%s)\n" "$bullet" "$path" "$desc"
        shown=$((shown + 1))
    done

    if [[ "$total" -gt "$max_show" ]]; then
        local remaining=$((total - max_show))
        printf "    %s ...plus %d more\n" "$bullet" "$remaining"
    fi
}

# --- Command summary helper ---------------------------------------------------

# _emit_summary_command — Extracts and formats one command for the banner.
# Args: $1 = commands output, $2 = type (test/build/analyze), $3 = label
# Returns: formatted string or empty
_emit_summary_command() {
    local commands="$1"
    local cmd_type="$2"
    local label="$3"
    [[ -z "$commands" ]] && return 0

    local cmd
    cmd=$(echo "$commands" | grep "^${cmd_type}|" | head -1 | cut -d'|' -f2 || true)
    [[ -z "$cmd" ]] && return 0

    printf "%s: %s" "$label" "$cmd"
}

# --- Attention item collector --------------------------------------------------

# _init_collect_attention — Collects attention items as bullet lines.
# Args: $1=project_dir, $2=commands, $3=file_count, $4=languages, $5=bullet
# Output: one line per attention item (empty if none)
_init_collect_attention() {
    local project_dir="$1"
    local commands="$2"
    local file_count="${3:-0}"
    local languages="$4"
    local bullet="$5"

    local _code_evidence=false
    if [[ -z "$languages" ]] || echo "$languages" | grep -qvF '|CLAUDE.md'; then
        _code_evidence=true
    fi

    if [[ -f "${project_dir}/.claude/pipeline.conf" ]]; then
        local _conf_arch=""
        _conf_arch=$(grep '^ARCHITECTURE_FILE=' "${project_dir}/.claude/pipeline.conf" 2>/dev/null | head -1 | cut -d'=' -f2- | tr -d '"' | tr -d "'" || true)
        if [[ -n "$_conf_arch" ]] && [[ ! -f "${project_dir}/${_conf_arch}" ]]; then
            echo "    ${bullet} ARCHITECTURE_FILE=\"${_conf_arch}\" not found"
        fi
    fi

    if [[ "$file_count" -gt 0 ]] && [[ "$_code_evidence" == "true" ]]; then
        local test_cmd
        test_cmd=$(_best_command "$commands" "test" 2>/dev/null || true)
        if [[ -z "$test_cmd" ]] || [[ "$test_cmd" == "true" ]]; then
            echo "    ${bullet} No test command detected"
        fi
    fi

    if [[ -n "$commands" ]]; then
        local cmd_type _cmd_val _cmd_src cmd_conf
        while IFS='|' read -r cmd_type _cmd_val _cmd_src cmd_conf; do
            [[ -z "$cmd_type" ]] && continue
            if [[ "$cmd_conf" == "low" ]] || [[ "$cmd_conf" == "medium" ]]; then
                echo "    ${bullet} ${cmd_type} command needs verification (${cmd_conf})"
            fi
        done <<< "$commands"
    fi
}

# --- Main banner -------------------------------------------------------------

# emit_init_summary — Prints three-part narrative post-init banner.
# Args: $1=project_dir, $2=languages, $3=frameworks, $4=commands,
#       $5=project_type, $6=file_count
# Globals read: _INIT_FILES_WRITTEN[], INIT_AUTO_PROMPT, DASHBOARD_ENABLED
emit_init_summary() {
    local project_dir="$1"
    local languages="$2"
    local frameworks="$3"
    local commands="$4"
    local project_type="$5"
    local file_count="${6:-0}"

    local project_name
    project_name=$(basename "$project_dir")

    # Unicode / NO_COLOR fallback
    local divider bullet arrow
    if [[ "${NO_COLOR:-}" == "1" ]] || ! _is_utf8_terminal 2>/dev/null; then
        divider=$(_build_box_hline 54 "=" 2>/dev/null || printf '%0.s=' {1..54})
        bullet="*"
        arrow=">"
    else
        divider=$(_build_box_hline 54 "━" 2>/dev/null || printf '%0.s━' {1..54})
        bullet="●"
        arrow="▶"
    fi

    # ── Header ──
    echo
    echo -e "  ${BOLD}${divider}${NC}"
    echo -e "  ${GREEN}${BOLD}Tekhton initialized for: ${project_name}${NC}"
    echo -e "  ${BOLD}${divider}${NC}"
    echo

    # ── What Tekhton learned ──
    echo -e "  ${BOLD}What Tekhton learned${NC}"
    _emit_learned_section "$languages" "$frameworks" "$commands" \
        "$project_type" "$file_count" "$project_dir" "$bullet"
    echo

    # ── What Tekhton wrote ──
    echo -e "  ${BOLD}What Tekhton wrote${NC}"
    if [[ "${#_INIT_FILES_WRITTEN[@]}" -gt 0 ]]; then
        _init_render_files_written "$bullet"
    else
        echo "    ${bullet} (no files written)"
    fi
    echo

    # ── What's next ──
    _emit_next_section "$project_dir" "$file_count" "$commands" \
        "$bullet" "$arrow"

    # ── Auto-prompt ──
    _emit_auto_prompt "$project_dir" "$file_count"
}

# _emit_learned_section — Renders the "What Tekhton learned" bullets.
_emit_learned_section() {
    local languages="$1"
    local frameworks="$2"
    local commands="$3"
    local project_type="$4"
    local file_count="$5"
    local project_dir="$6"
    local bullet="$7"

    # Language + framework summary line
    local lang_desc=""
    if [[ -n "$languages" ]]; then
        local first_lang
        first_lang=$(echo "$languages" | head -1 | cut -d'|' -f1)
        lang_desc="${first_lang} project"
        if [[ -n "$frameworks" ]]; then
            local first_fw
            first_fw=$(echo "$frameworks" | head -1 | cut -d'|' -f1)
            lang_desc="${first_lang} project (${first_fw}"
            local first_fw_src
            first_fw_src=$(echo "$frameworks" | head -1 | cut -d'|' -f3)
            lang_desc="${lang_desc}, from ${first_fw_src})"
        fi
        echo "    ${bullet} ${lang_desc}, ${file_count} source files"
    else
        echo "    ${bullet} ${file_count} files (no language detected)"
    fi

    # Commands summary
    local cmd_parts=""
    local build_str test_str lint_str
    build_str=$(_emit_summary_command "$commands" "build" "Build")
    test_str=$(_emit_summary_command "$commands" "test" "Test")
    lint_str=$(_emit_summary_command "$commands" "analyze" "Lint")
    for part in "$build_str" "$test_str" "$lint_str"; do
        [[ -z "$part" ]] && continue
        if [[ -z "$cmd_parts" ]]; then
            cmd_parts="$part"
        else
            cmd_parts="${cmd_parts}   ${part}"
        fi
    done
    if [[ -n "$cmd_parts" ]]; then
        echo "    ${bullet} ${cmd_parts}"
    fi

    # Health score with attention count
    local attention_lines
    attention_lines=$(_init_collect_attention "$project_dir" "$commands" "$file_count" "$languages" "$bullet")
    local attention_count=0
    if [[ -n "$attention_lines" ]]; then
        attention_count=$(echo "$attention_lines" | wc -l | tr -d '[:space:]')
    fi

    local health_line=""
    if type -t compute_health_score &>/dev/null; then
        local health_score
        health_score=$(compute_health_score "$project_dir" 2>/dev/null || echo "")
        if [[ -n "$health_score" ]]; then
            health_line="Health score: ${health_score}/100"
        fi
    fi
    if [[ -n "$health_line" ]]; then
        if [[ "$attention_count" -gt 0 ]]; then
            echo "    ${bullet} ${health_line} (${attention_count} items need attention)"
        else
            echo "    ${bullet} ${health_line}"
        fi
    fi

    # Print individual attention items
    if [[ -n "$attention_lines" ]]; then
        echo "$attention_lines"
    fi
}

# _emit_next_section — Renders the "What's next" block with recommendation.
_emit_next_section() {
    local project_dir="$1"
    local file_count="$2"
    local commands="$3"
    local bullet="$4"
    local arrow="$5"

    # Detect milestone state
    local has_manifest=false has_pending=false
    local _milestone_dir="${project_dir}/.claude/milestones"
    local _claude_md="${project_dir}/CLAUDE.md"
    if [[ -f "${_milestone_dir}/MANIFEST.cfg" ]] \
        && grep -q '|' "${_milestone_dir}/MANIFEST.cfg" 2>/dev/null; then
        has_manifest=true
        if grep -qE '\|pending\||\|in_progress\|' "${_milestone_dir}/MANIFEST.cfg" 2>/dev/null; then
            has_pending=true
        fi
    elif [[ -f "$_claude_md" ]] \
        && ! grep -q '<!-- TODO:.*--plan' "$_claude_md" 2>/dev/null \
        && grep -q '^#### Milestone' "$_claude_md" 2>/dev/null; then
        has_manifest=true
        has_pending=true
    fi

    local rec_line
    rec_line=$(_init_pick_recommendation "$file_count" "$has_manifest" "$has_pending")
    local rec_cmd rec_desc alt1 alt2
    rec_cmd=$(echo "$rec_line" | cut -d'|' -f1)
    rec_desc=$(echo "$rec_line" | cut -d'|' -f2)
    alt1=$(echo "$rec_line" | cut -d'|' -f3)
    alt2=$(echo "$rec_line" | cut -d'|' -f4)

    echo -e "  ${BOLD}What's next${NC}"
    echo -e "    ${GREEN}${arrow}${NC}  ${BOLD}${rec_cmd}${NC}   (${rec_desc})"
    [[ -n "$alt1" ]] && echo "       or ${alt1}"
    [[ -n "$alt2" ]] && echo "       or ${alt2}"
    echo

    # Report pointer
    if _is_watchtower_enabled; then
        echo -e "  Full report: ${CYAN}.claude/dashboard/index.html${NC}"
    else
        echo -e "  Full report: ${CYAN}INIT_REPORT.md${NC}"
    fi
    echo -e "  Run ${CYAN}tekhton --help${NC} for all commands."
    echo
}

# _emit_auto_prompt — Optional auto-prompt to run recommended command.
_emit_auto_prompt() {
    local project_dir="$1"
    local file_count="$2"

    [[ "${INIT_AUTO_PROMPT:-false}" != "true" ]] && return 0
    [[ ! -t 0 ]] && return 0
    [[ ! -t 1 ]] && return 0

    # Re-derive recommendation (mirrors logic in _emit_next_section)
    local has_manifest=false has_pending=false
    local _milestone_dir="${project_dir}/.claude/milestones"
    local _claude_md="${project_dir}/CLAUDE.md"
    if [[ -f "${_milestone_dir}/MANIFEST.cfg" ]] \
        && grep -q '|' "${_milestone_dir}/MANIFEST.cfg" 2>/dev/null; then
        has_manifest=true
        if grep -qE '\|pending\||\|in_progress\|' "${_milestone_dir}/MANIFEST.cfg" 2>/dev/null; then
            has_pending=true
        fi
    elif [[ -f "$_claude_md" ]] \
        && ! grep -q '<!-- TODO:.*--plan' "$_claude_md" 2>/dev/null \
        && grep -q '^#### Milestone' "$_claude_md" 2>/dev/null; then
        has_manifest=true
        has_pending=true
    fi

    local rec_line
    rec_line=$(_init_pick_recommendation "$file_count" "$has_manifest" "$has_pending")
    local rec_cmd
    rec_cmd=$(echo "$rec_line" | cut -d'|' -f1)

    local _reply
    read -r -p "  Run ${rec_cmd} now? [Y/n] " _reply </dev/tty || return 0
    case "${_reply:-Y}" in
        y|Y|yes|Yes|YES|"")
            # Split rec_cmd into array to properly handle multi-word commands
            local _cmd_array
            read -ra _cmd_array <<< "$rec_cmd"
            exec "${_cmd_array[@]}"
            ;;
        *) : ;;
    esac
}
