#!/usr/bin/env bash
# =============================================================================
# plan.sh — Planning phase orchestration
#
# Provides the interactive planning flow: project type selection, template
# resolution, interactive interview, completeness check, and generation.
# Sourced by tekhton.sh when --plan is passed. Do not run directly.
# =============================================================================

# --- Constants ---------------------------------------------------------------

PLAN_TEMPLATES_DIR="${TEKHTON_HOME}/templates/plans"
# Used by lib/plan_state.sh (sourced separately)
# shellcheck disable=SC2034
PLAN_STATE_FILE="${PROJECT_DIR:-}/.claude/PLAN_STATE.md"

# --- Planning config loader --------------------------------------------------
# Reads planning-specific keys from pipeline.conf if it exists. Called before
# applying defaults so pipeline.conf values take precedence over env vars.

load_plan_config() {
    local conf_file="${PROJECT_DIR:-}/.claude/pipeline.conf"
    if [[ -f "$conf_file" ]]; then
        # Use the safe config parser from config.sh if available (execution pipeline),
        # otherwise use a minimal inline parser (--plan mode, config.sh not sourced).
        if declare -f _parse_config_file &>/dev/null; then
            _parse_config_file "$conf_file"
        else
            # Minimal safe parser for --plan mode: reads key=value lines,
            # rejects command substitution ($( and backticks).
            local _line_num=0
            while IFS= read -r _line || [[ -n "$_line" ]]; do
                _line_num=$((_line_num + 1))
                _line="${_line//$'\r'/}"
                [[ -z "$_line" ]] && continue
                [[ "$_line" =~ ^[[:space:]]*# ]] && continue
                if ! [[ "$_line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*) ]]; then
                    continue
                fi
                local _key="${BASH_REMATCH[1]}"
                local _val="${BASH_REMATCH[2]}"
                _val="${_val#"${_val%%[![:space:]]*}"}"
                _val="${_val%"${_val##*[![:space:]]}"}"
                if [[ "$_val" =~ ^\"(.*)\"$ ]]; then
                    _val="${BASH_REMATCH[1]}"
                elif [[ "$_val" =~ ^\'(.*)\'$ ]]; then
                    _val="${BASH_REMATCH[1]}"
                fi
                if [[ "$_val" == *"\$("* ]] || [[ "$_val" == *"\`"* ]]; then
                    echo "[✗] pipeline.conf:${_line_num}: REJECTED — value for '${_key}' contains command substitution." >&2
                    exit 1
                fi
                declare -gx "$_key=$_val"
            done < "$conf_file"
        fi
    fi
}

# Load config if available, then apply defaults for anything not set.
load_plan_config

# --- Planning config defaults ------------------------------------------------
# Overridable via environment variables or pipeline.conf.

export PLAN_INTERVIEW_MODEL="${PLAN_INTERVIEW_MODEL:-${CLAUDE_PLAN_MODEL:-opus}}"
export PLAN_INTERVIEW_MAX_TURNS="${PLAN_INTERVIEW_MAX_TURNS:-50}"
export PLAN_GENERATION_MODEL="${PLAN_GENERATION_MODEL:-${CLAUDE_PLAN_MODEL:-opus}}"
export PLAN_GENERATION_MAX_TURNS="${PLAN_GENERATION_MAX_TURNS:-50}"

# Replan defaults (used by --replan command)
export REPLAN_MODEL="${REPLAN_MODEL:-${PLAN_GENERATION_MODEL}}"
export REPLAN_MAX_TURNS="${REPLAN_MAX_TURNS:-${PLAN_GENERATION_MAX_TURNS}}"

# Project types — order matches the menu display
PLAN_PROJECT_TYPES=(
    "web-app"
    "web-game"
    "cli-tool"
    "api-service"
    "mobile-app"
    "library"
    "custom"
)

PLAN_PROJECT_LABELS=(
    "Web Application      (React, Next.js, Django, Rails, etc.)"
    "Web Game              (browser-based game with HTML5/Canvas/WebGL)"
    "CLI Tool              (command-line utility or developer tool)"
    "API Service           (REST/GraphQL backend, microservice)"
    "Mobile App            (iOS, Android, React Native, Flutter)"
    "Library / Package     (reusable module published to a registry)"
    "Custom                (anything else — minimal template)"
)
# --- Project Type Selection --------------------------------------------------

# Displays the project type menu and reads the user's choice.
# Sets PLAN_PROJECT_TYPE and PLAN_TEMPLATE_FILE on success.
select_project_type() {
    echo
    header "Tekhton Plan — Project Type Selection"
    echo "  What kind of project are you building?"
    echo

    local i
    for i in "${!PLAN_PROJECT_TYPES[@]}"; do
        printf "  %d) %s\n" "$((i + 1))" "${PLAN_PROJECT_LABELS[$i]}"
    done
    echo

    # Use /dev/tty when stdin is not a terminal (e.g., piped input from scripts).
    # TEKHTON_TEST_MODE disables this so tests can pipe input via stdin.
    local input_fd="/dev/stdin"
    if [[ ! -t 0 ]] && [[ -e /dev/tty ]] && [[ -z "${TEKHTON_TEST_MODE:-}" ]]; then
        input_fd="/dev/tty"
    fi

    local choice
    while true; do
        printf "  Select [1-%d]: " "${#PLAN_PROJECT_TYPES[@]}"
        read -r choice < "$input_fd" || { error "Unexpected end of input."; return 1; }
        choice="${choice//$'\r'/}"

        # Validate: must be a number in range
        if [[ "$choice" =~ ^[0-9]+$ ]] && \
           [ "$choice" -ge 1 ] && \
           [ "$choice" -le "${#PLAN_PROJECT_TYPES[@]}" ]; then
            PLAN_PROJECT_TYPE="${PLAN_PROJECT_TYPES[$((choice - 1))]}"
            PLAN_TEMPLATE_FILE="${PLAN_TEMPLATES_DIR}/${PLAN_PROJECT_TYPE}.md"

            if [ ! -f "$PLAN_TEMPLATE_FILE" ]; then
                error "Template not found: ${PLAN_TEMPLATE_FILE}"
                error "This is a bug in Tekhton — the template should exist."
                return 1
            fi

            success "Selected: ${PLAN_PROJECT_TYPE}"
            log "Template: ${PLAN_TEMPLATE_FILE}"
            return 0
        else
            warn "Invalid choice '${choice}'. Please enter a number between 1 and ${#PLAN_PROJECT_TYPES[@]}."
        fi
    done
}
# --- Completeness Check ------------------------------------------------------
# Extracted to lib/plan_completeness.sh — sourced separately by tekhton.sh.

# --- Planning State Persistence ----------------------------------------------
# Extracted to lib/plan_state.sh — sourced separately by tekhton.sh.

# --- Batch Planning Call Helper ----------------------------------------------

# _call_planning_batch — Call claude in batch mode and print text content to stdout.
#
# Uses --output-format text so the response is plain text with no JSON parsing.
# Does NOT use --dangerously-skip-permissions — planning agents generate text
# only; the caller (shell) is responsible for writing any files.
#
# The response is tee'd to the log file and also passed through to stdout so
# the caller can capture it with output=$(_call_planning_batch ...).
#
# Shows a progress indicator on /dev/tty while claude is running so the user
# knows the operation hasn't stalled. Skipped in TEKHTON_TEST_MODE.
#
# Usage:
#   output=$(_call_planning_batch model max_turns prompt log_file)
#   rc=$?   # claude's exit code
#
# Prints the full text response to stdout. Returns claude's exit code.
_call_planning_batch() {
    local model="$1"
    local max_turns="$2"
    local prompt="$3"
    local log_file="$4"

    # Start an in-place spinner on /dev/tty (visible even inside $() capture).
    # Animates a single line with elapsed time so the user knows it's working
    # without flooding the terminal with output over 20+ minute runs.
    local spinner_pid=""
    if [[ -z "${TEKHTON_TEST_MODE:-}" ]] && [[ -e /dev/tty ]]; then
        (
            local chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
            local start_ts
            start_ts=$(date +%s)
            local i=0
            while true; do
                local now
                now=$(date +%s)
                local elapsed=$(( now - start_ts ))
                local mins=$(( elapsed / 60 ))
                local secs=$(( elapsed % 60 ))
                printf '\r\033[0;36m[tekhton]\033[0m %s Generating... %dm%02ds ' \
                    "${chars:i%${#chars}:1}" "$mins" "$secs" > /dev/tty
                i=$(( i + 1 ))
                sleep 0.2
            done
        ) &
        spinner_pid=$!
    fi

    set +o pipefail
    claude \
        --model "$model" \
        --max-turns "$max_turns" \
        --output-format text \
        -p "$prompt" \
        < /dev/null \
        2>&1 | tee -a "$log_file"
    local -a _pst=("${PIPESTATUS[@]}")
    set -o pipefail

    # Stop spinner and clear the line
    if [[ -n "$spinner_pid" ]]; then
        kill "$spinner_pid" 2>/dev/null || true
        wait "$spinner_pid" 2>/dev/null || true
        printf '\r\033[K' > /dev/tty 2>/dev/null || true
    fi

    return "${_pst[0]}"
}

# _extract_template_sections — Parse a template file and print section data.
#
# Output format (one line per section):   NAME|REQUIRED|GUIDANCE|PHASE
#   NAME     — section heading (without "## " prefix)
#   REQUIRED — "true" or "false"
#   GUIDANCE — single-line concatenation of <!-- ... --> guidance comments
#   PHASE    — integer (1, 2, or 3) from <!-- PHASE:N --> marker; default 1
#
# Usage:
#   while IFS='|' read -r name required guidance phase; do
#       ...
#   done < <(_extract_template_sections "$template_file")
_extract_template_sections() {
    local template="$1"
    awk '
    BEGIN { section = ""; required = "false"; guidance = ""; phase = "1" }
    /^## / {
        if (section != "") {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", guidance)
            print section "|" required "|" guidance "|" phase
        }
        section = $0
        sub(/^## /, "", section)
        required = "false"
        guidance = ""
        phase = "1"
        if (section ~ /<!-- REQUIRED -->/) {
            required = "true"
            gsub(/[[:space:]]*<!-- REQUIRED -->[[:space:]]*/, "", section)
        }
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", section)
        next
    }
    section != "" && /^<!-- REQUIRED -->/ { required = "true"; next }
    section != "" && /^<!-- PHASE:[0-9]+ -->/ {
        line = $0
        gsub(/^<!-- PHASE:/, "", line)
        gsub(/[[:space:]]*-->.*/, "", line)
        phase = line
        next
    }
    section != "" && /^<!--/ {
        line = $0
        gsub(/^<!--[[:space:]]*/, "", line)
        gsub(/[[:space:]]*-->$/, "", line)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        if (length(line) > 0 && line != "REQUIRED") {
            guidance = (guidance == "") ? line : guidance " " line
        }
        next
    }
    END {
        if (section != "") {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", guidance)
            print section "|" required "|" guidance "|" phase
        }
    }
    ' "$template"
}

# --- Codebase Summary Generator -----------------------------------------------

# _generate_codebase_summary — Produces a bounded directory tree + recent git log.
# Output is capped at ~200 lines of tree + 20 git log entries to prevent
# oversized prompts in large monorepos.
# Returns the summary on stdout.
_generate_codebase_summary() {
    local summary=""

    # Directory tree (depth-limited, capped at 200 lines)
    if command -v tree &>/dev/null; then
        summary+="### Directory Tree (depth 3)"$'\n'
        summary+=$(tree -L 3 --noreport -I 'node_modules|.git|__pycache__|.dart_tool|build|dist|.next' \
            "$PROJECT_DIR" 2>/dev/null | head -200 || true)
        summary+=$'\n'
    else
        # Fallback: find-based listing
        summary+="### Directory Listing (depth 3)"$'\n'
        summary+=$(find "$PROJECT_DIR" -maxdepth 3 \
            -not -path '*/.git/*' \
            -not -path '*/node_modules/*' \
            -not -path '*/__pycache__/*' \
            -not -path '*/build/*' \
            -not -path '*/dist/*' \
            -not -path '*/.next/*' \
            -type f 2>/dev/null | sort | head -200 || true)
        summary+=$'\n'
    fi

    # Recent git log (last 20 commits)
    if git -C "$PROJECT_DIR" rev-parse --git-dir &>/dev/null; then
        summary+=$'\n'"### Recent Git History (last 20 commits)"$'\n'
        summary+=$(git -C "$PROJECT_DIR" log --oneline -20 2>/dev/null || true)
        summary+=$'\n'
    else
        summary+=$'\n'"### Git History"$'\n'"(Not a git repository)"$'\n'
    fi

    printf '%s' "$summary"
}

# --- Brownfield Replan --------------------------------------------------------

# run_replan — Top-level --replan orchestrator.
# Validates prerequisites, assembles context, calls the replan agent,
# writes output to DESIGN_DELTA.md, and presents approval menu.
# If approved, merges delta into DESIGN.md and regenerates CLAUDE.md.
run_replan() {
    local design_file="${PROJECT_DIR}/DESIGN.md"
    local claude_file="${PROJECT_DIR}/CLAUDE.md"

    header "Tekhton — Brownfield Replan"

    # --- Prerequisite validation ---
    if [[ ! -f "$design_file" ]] && [[ ! -f "$claude_file" ]]; then
        error "Neither DESIGN.md nor CLAUDE.md found at ${PROJECT_DIR}."
        error "The --replan command requires an existing project created with --plan."
        error "Run 'tekhton --plan' first to create these files."
        return 1
    fi

    if [[ ! -f "$claude_file" ]]; then
        error "CLAUDE.md not found at ${PROJECT_DIR}."
        error "The --replan command requires an existing CLAUDE.md."
        return 1
    fi

    # --- Assemble context ---
    log "Assembling replan context..."

    # Read DESIGN.md (optional — project may only have CLAUDE.md)
    export DESIGN_CONTENT=""
    export NO_DESIGN=""
    if [[ -f "$design_file" ]]; then
        DESIGN_CONTENT=$(_safe_read_file "$design_file" "DESIGN")
    else
        NO_DESIGN="true"
        warn "No DESIGN.md found — replan will focus on CLAUDE.md only."
    fi

    # Read CLAUDE.md
    export CLAUDE_CONTENT=""
    CLAUDE_CONTENT=$(_safe_read_file "$claude_file" "CLAUDE")

    # Read drift log
    export DRIFT_LOG_CONTENT=""
    export NO_DRIFT_LOG=""
    local drift_file="${PROJECT_DIR}/${DRIFT_LOG_FILE:-DRIFT_LOG.md}"
    if [[ -f "$drift_file" ]]; then
        DRIFT_LOG_CONTENT=$(_safe_read_file "$drift_file" "DRIFT_LOG")
    else
        NO_DRIFT_LOG="true"
    fi

    # Read architecture decision log
    export ARCHITECTURE_LOG_CONTENT=""
    export NO_ARCHITECTURE_LOG=""
    local adl_file="${PROJECT_DIR}/${ARCHITECTURE_LOG_FILE:-ARCHITECTURE_LOG.md}"
    if [[ -f "$adl_file" ]]; then
        ARCHITECTURE_LOG_CONTENT=$(_safe_read_file "$adl_file" "ARCHITECTURE_LOG")
    else
        NO_ARCHITECTURE_LOG="true"
    fi

    # Read human action items
    export HUMAN_ACTION_CONTENT=""
    export NO_HUMAN_ACTION=""
    local action_file="${PROJECT_DIR}/${HUMAN_ACTION_FILE:-HUMAN_ACTION_REQUIRED.md}"
    if [[ -f "$action_file" ]]; then
        HUMAN_ACTION_CONTENT=$(_safe_read_file "$action_file" "HUMAN_ACTION")
    else
        NO_HUMAN_ACTION="true"
    fi

    # Generate codebase summary
    export CODEBASE_SUMMARY=""
    log "Generating codebase summary..."
    CODEBASE_SUMMARY=$(_generate_codebase_summary)

    # --- Render and run replan agent ---
    local replan_prompt
    replan_prompt=$(render_prompt "replan")

    local log_dir="${PROJECT_DIR}/.claude/logs"
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local log_file="${log_dir}/${timestamp}_replan.log"
    mkdir -p "$log_dir"

    log "Model: ${REPLAN_MODEL}"
    log "Max turns: ${REPLAN_MAX_TURNS}"
    log "Log: ${log_file}"
    echo
    log "Running replan agent..."

    # Write session metadata to log
    {
        echo "=== Tekhton Brownfield Replan ==="
        echo "Date: $(date)"
        echo "Model: ${REPLAN_MODEL}"
        echo "Max Turns: ${REPLAN_MAX_TURNS}"
        echo "=== Session Start ==="
    } > "$log_file"

    local replan_output=""
    local batch_exit=0
    replan_output=$(_call_planning_batch \
        "$REPLAN_MODEL" \
        "$REPLAN_MAX_TURNS" \
        "$replan_prompt" \
        "$log_file") || batch_exit=$?

    {
        echo "=== Session End ==="
        echo "Exit code: ${batch_exit}"
        echo "Date: $(date)"
    } >> "$log_file"

    echo

    if [[ -z "$replan_output" ]]; then
        error "Replan agent produced no output."
        [[ "$batch_exit" -ne 0 ]] && error "Claude exited with code ${batch_exit}."
        log "Log saved: ${log_file}"
        return 1
    fi

    # --- Write delta and present approval menu ---
    local delta_file="${PROJECT_DIR}/REPLAN_DELTA.md"
    printf '%s\n' "$replan_output" > "$delta_file"
    local delta_lines
    delta_lines=$(wc -l < "$delta_file")
    success "Replan delta written to REPLAN_DELTA.md (${delta_lines} lines)."
    log "Log saved: ${log_file}"

    echo
    _replan_approval_menu "$delta_file"
}

# _replan_approval_menu — Displays the delta and prompts for approval.
# Options: [a] Apply  [e] Edit  [n] Reject
_replan_approval_menu() {
    local delta_file="$1"
    local design_file="${PROJECT_DIR}/DESIGN.md"
    local claude_file="${PROJECT_DIR}/CLAUDE.md"

    # Determine input source
    local input_fd="/dev/stdin"
    if [[ ! -t 0 ]] && [[ -e /dev/tty ]] && [[ -z "${TEKHTON_TEST_MODE:-}" ]]; then
        input_fd="/dev/tty"
    fi

    local choice
    while true; do
        header "Replan Delta Review"
        echo "  Review the proposed changes in REPLAN_DELTA.md"
        echo
        echo "  Options:"
        echo "    [a] Apply   — merge changes into DESIGN.md and regenerate CLAUDE.md"
        echo "    [e] Edit    — open delta in \${EDITOR:-nano} before applying"
        echo "    [n] Reject  — discard delta"
        echo
        printf "  Select [a/e/n]: "
        read -r choice < "$input_fd" || { warn "End of input"; choice="n"; }
        choice="${choice//$'\r'/}"

        case "$choice" in
            a|A)
                _apply_brownfield_delta "$delta_file"
                return $?
                ;;
            e|E)
                "${EDITOR:-nano}" "$delta_file" || warn "Editor exited with non-zero status"
                log "Editor closed. Re-showing menu..."
                ;;
            n|N)
                log "Replan rejected. No changes applied."
                # Archive the delta for reference
                _archive_replan_delta "$delta_file"
                return 0
                ;;
            *)
                warn "Invalid choice '${choice}'. Please enter a, e, or n."
                ;;
        esac
    done
}

# _apply_brownfield_delta — Apply the replan delta to DESIGN.md and regenerate CLAUDE.md.
# The delta is appended as a replan note to DESIGN.md (preserving existing content).
# Then CLAUDE.md is regenerated from the updated DESIGN.md.
_apply_brownfield_delta() {
    local delta_file="$1"
    local design_file="${PROJECT_DIR}/DESIGN.md"
    local claude_file="${PROJECT_DIR}/CLAUDE.md"

    if [[ ! -f "$delta_file" ]]; then
        error "Delta file not found: ${delta_file}"
        return 1
    fi

    # Append the delta as a replan section in DESIGN.md (if it exists)
    if [[ -f "$design_file" ]]; then
        {
            echo ""
            echo "<!-- Replan applied: $(date '+%Y-%m-%d %H:%M:%S') -->"
            echo "## Replan Delta"
            echo ""
            cat "$delta_file"
        } >> "$design_file"
        success "Delta appended to DESIGN.md."
    else
        warn "No DESIGN.md to update — skipping DESIGN.md merge."
    fi

    # Regenerate CLAUDE.md from updated DESIGN.md
    if [[ -f "$design_file" ]]; then
        echo
        log "Regenerating CLAUDE.md from updated DESIGN.md..."

        # Preserve completed milestones from existing CLAUDE.md
        local completed_milestones=""
        if [[ -f "$claude_file" ]]; then
            completed_milestones=$(awk '
                /^####.*\[DONE\]/ { collecting=1; print; next }
                collecting && /^####/ && !/\[DONE\]/ { collecting=0; next }
                collecting && /^###[^#]/ { collecting=0; next }
                collecting && /^##[^#]/ { collecting=0; next }
                collecting { print }
            ' "$claude_file" 2>/dev/null || true)
        fi
        export COMPLETED_MILESTONES="$completed_milestones"

        # Source plan_generate.sh if not already sourced
        if ! declare -f run_plan_generate &>/dev/null; then
            if [[ -f "${TEKHTON_HOME}/stages/plan_generate.sh" ]]; then
                # shellcheck source=stages/plan_generate.sh
                source "${TEKHTON_HOME}/stages/plan_generate.sh"
            else
                warn "Cannot regenerate CLAUDE.md: stages/plan_generate.sh not found."
                warn "Apply the CLAUDE.md delta manually from REPLAN_DELTA.md."
                _archive_replan_delta "$delta_file"
                return 0
            fi
        fi

        run_plan_generate || {
            warn "CLAUDE.md regeneration failed. Apply the delta manually."
            _archive_replan_delta "$delta_file"
            return 0
        }

        success "CLAUDE.md regenerated successfully."
    else
        # No DESIGN.md — apply delta directly to CLAUDE.md
        {
            echo ""
            echo "<!-- Replan applied: $(date '+%Y-%m-%d %H:%M:%S') -->"
            echo "## Replan Note"
            echo ""
            cat "$delta_file"
        } >> "$claude_file"
        success "Delta appended to CLAUDE.md."
    fi

    # Archive the delta
    _archive_replan_delta "$delta_file"

    echo
    success "Brownfield replan complete!"
    log "Review the updated files:"
    if [[ -f "$design_file" ]]; then
        log "  DESIGN.md — replan delta appended"
    fi
    log "  CLAUDE.md — regenerated from updated design"
    echo
}

# _archive_replan_delta — Move the delta file to the logs archive.
_archive_replan_delta() {
    local delta_file="$1"
    if [[ ! -f "$delta_file" ]]; then
        return 0
    fi
    local archive_dir="${PROJECT_DIR}/.claude/logs/archive"
    mkdir -p "$archive_dir" 2>/dev/null || true
    mv "$delta_file" "${archive_dir}/$(date +%Y%m%d_%H%M%S)_REPLAN_DELTA.md" 2>/dev/null || true
}

# --- Main Entry Point --------------------------------------------------------

# run_plan — Top-level planning phase orchestrator.
# Supports resume from interrupted sessions via PLAN_STATE_FILE.
run_plan() {
    header "Tekhton — Planning Phase"
    log "This will guide you through creating DESIGN.md and CLAUDE.md for your project."
    echo

    # Check for interrupted session and offer resume
    local resume_rc=0
    _offer_plan_resume || resume_rc=$?

    if [[ "$resume_rc" -eq 2 ]]; then
        # User aborted
        return 1
    fi

    local skip_to="${PLAN_RESUME_STAGE:-}"

    # Step 1: Project type selection (skip if resuming past this stage)
    if [[ -z "$skip_to" ]]; then
        select_project_type || return 1
        write_plan_state "interview" "$PLAN_PROJECT_TYPE" "$PLAN_TEMPLATE_FILE"
    fi

    # Step 2: Interactive interview (skip if resuming past this stage)
    if [[ -z "$skip_to" ]] || [[ "$skip_to" == "interview" ]]; then
        echo
        run_plan_interview || return 1
        write_plan_state "completeness" "$PLAN_PROJECT_TYPE" "$PLAN_TEMPLATE_FILE"
        skip_to=""
    fi

    # Step 3: Completeness check + follow-up loop
    if [[ -z "$skip_to" ]] || [[ "$skip_to" == "completeness" ]]; then
        echo
        run_plan_completeness_loop || return 1
        write_plan_state "generation" "$PLAN_PROJECT_TYPE" "$PLAN_TEMPLATE_FILE"
        skip_to=""
    fi

    # Step 4: CLAUDE.md generation
    if [[ -z "$skip_to" ]] || [[ "$skip_to" == "generation" ]]; then
        echo
        run_plan_generate || return 1
        write_plan_state "review" "$PLAN_PROJECT_TYPE" "$PLAN_TEMPLATE_FILE"
        skip_to=""
    fi

    # Step 5: Milestone review + file output
    # No skip_to guard — review is always the final step after generation,
    # so we always run it regardless of resume state.
    echo
    run_plan_review || return 1

    # Success — clear state
    clear_plan_state
}

# --- Milestone Review UI ----------------------------------------------------

# _display_milestone_summary — Show the milestone review screen.
# Reads the file once and extracts both project name and milestones.
_display_milestone_summary() {
    local claude_file="$1"
    local file_content
    file_content=$(cat "$claude_file" 2>/dev/null || true)

    local project_name
    project_name=$(echo "$file_content" | grep -m 1 '^# ' | sed 's/^# //')
    if [[ -z "$project_name" ]]; then
        project_name=$(basename "$PROJECT_DIR")
    fi

    local milestones
    milestones=$(echo "$file_content" | grep -E '^#{2,3} Milestone [0-9]+' | sed 's/^#* //' || true)
    local milestone_count
    milestone_count=$(echo "$milestones" | grep -c '.' || true)

    header "Tekhton Plan — Milestone Summary"
    echo "  Project: ${project_name}"
    echo "  Milestones: ${milestone_count}"
    echo

    if [[ -n "$milestones" ]]; then
        echo "$milestones" | while IFS= read -r line; do
            echo "  ${line}"
        done
    else
        warn "  No milestone headings found in CLAUDE.md."
        warn "  The file may use a different heading format."
    fi

    echo
    echo "  [y] Accept and write files"
    echo "  [e] Edit CLAUDE.md in \${EDITOR:-nano}"
    echo "  [r] Re-generate with same DESIGN.md"
    echo "  [n] Abort without writing files"
    echo
}

# _print_next_steps — Instructions printed after successful file write.
_print_next_steps() {
    echo
    success "Planning phase complete!"
    echo
    log "Your files:"
    log "  DESIGN.md  — project design document"
    log "  CLAUDE.md  — project rules and milestone plan"
    echo
    log "Next steps:"
    log "  1. Review the generated files and make any manual edits"
    log "  2. Run: tekhton --init    (scaffold pipeline config)"
    log "  3. Run: tekhton \"Implement Milestone 1: <title>\""
    echo
}

# run_plan_review — Interactive milestone review loop.
#
# Displays the milestone summary and prompts the user to accept, edit,
# re-generate, or abort. Loops until the user accepts or aborts.
#
# Returns 0 on accept, 1 on abort.
run_plan_review() {
    local claude_file="${PROJECT_DIR}/CLAUDE.md"
    local design_file="${PROJECT_DIR}/DESIGN.md"

    if [[ ! -f "$claude_file" ]]; then
        error "CLAUDE.md not found — nothing to review."
        return 1
    fi

    # Use /dev/tty for interactive input when stdin is not a terminal,
    # unless running in test mode.
    local input_fd="/dev/stdin"
    if [[ ! -t 0 ]] && [[ -e /dev/tty ]] && [[ -z "${TEKHTON_TEST_MODE:-}" ]]; then
        input_fd="/dev/tty"
    fi

    local choice
    while true; do
        _display_milestone_summary "$claude_file"
        printf "  Select [y/e/r/n]: "
        read -r choice < "$input_fd" || { warn "End of input — accepting files."; choice="y"; }
        choice="${choice//$'\r'/}"

        case "$choice" in
            y|Y)
                success "Files confirmed at ${PROJECT_DIR}:"
                log "  DESIGN.md"
                log "  CLAUDE.md"
                _print_next_steps
                return 0
                ;;
            e|E)
                log "Opening CLAUDE.md in editor..."
                "${EDITOR:-nano}" "$claude_file" || warn "Editor exited with non-zero status"
                log "Editor closed. Refreshing milestone summary..."
                ;;
            r|R)
                log "Re-generating CLAUDE.md from DESIGN.md..."
                echo
                run_plan_generate || return 1
                ;;
            n|N)
                warn "Aborted. DESIGN.md is preserved at: ${design_file}"
                warn "CLAUDE.md is preserved at: ${claude_file}"
                log "Re-run 'tekhton --plan' to try again."
                return 1
                ;;
            *)
                warn "Invalid choice '${choice}'. Please enter y, e, r, or n."
                ;;
        esac
    done
}
