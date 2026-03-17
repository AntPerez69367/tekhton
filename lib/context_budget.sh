#!/usr/bin/env bash
set -euo pipefail
# =============================================================================
# context_budget.sh — Context budget enforcement (Milestone 2)
#
# Sourced by lib/context_compiler.sh — do not run directly.
# Expects: log(), warn(), count_lines() from common.sh
#          check_context_budget() from context.sh
#          compress_context() from context_compiler.sh
# Provides: _filter_block(), _estimate_block_tokens(), _compress_if_over_budget()
# =============================================================================

# --- _filter_block — Filters a named context block variable by keywords ---
# If filtering produces empty output, falls back to the original content.

_filter_block() {
    local var_name="$1"
    local keywords="$2"

    local original="${!var_name:-}"
    if [[ -z "$original" ]]; then
        return
    fi

    local filtered
    filtered=$(extract_relevant_sections "$original" "$keywords")

    if [[ -z "$filtered" ]] || [[ "$filtered" = "$original" ]]; then
        return  # No change or empty result — keep original
    fi

    # If the original had ## headings but the filtered result has none,
    # that means no sections matched keywords — only preamble survived.
    # Fall back to original to preserve full context (spec: "zero matches → full artifact").
    local orig_has_headings filtered_has_headings
    orig_has_headings=$(echo "$original" | grep -c '^## ' || true)
    filtered_has_headings=$(echo "$filtered" | grep -c '^## ' || true)
    if [[ "$orig_has_headings" -gt 0 ]] && [[ "$filtered_has_headings" -eq 0 ]]; then
        return  # Preamble-only result — keep original
    fi

    local orig_lines filtered_lines
    orig_lines=$(echo "$original" | count_lines)
    filtered_lines=$(echo "$filtered" | count_lines)

    # Only use filtered version if it actually reduced content
    if [[ "$filtered_lines" -lt "$orig_lines" ]]; then
        log "[context-compiler] ${var_name}: filtered from ${orig_lines} to ${filtered_lines} lines"
        export "$var_name=$filtered"
    fi
}

# --- _estimate_block_tokens — Estimates total token count for a set of block variables ---
# Sums character counts and converts to tokens using CHARS_PER_TOKEN.

_estimate_block_tokens() {
    local -n block_vars_ref="$1"
    local total_chars=0
    local i
    for i in "${!block_vars_ref[@]}"; do
        local val="${!block_vars_ref[$i]:-}"
        total_chars=$(( total_chars + ${#val} ))
    done
    local cpt="${CHARS_PER_TOKEN:-4}"
    echo $(( (total_chars + cpt - 1) / cpt ))
}

# --- _compress_if_over_budget — Applies compression to largest non-essential blocks ---
# Compression priority (compress first → last):
#   1. Prior tester context
#   2. Non-blocking notes
#   3. Prior progress context
# Never compresses: architecture (coder), task, human notes

_compress_if_over_budget() {
    local stage="$1"
    local model="$2"

    # Estimate current total
    # shellcheck disable=SC2034  # block_vars is passed to _estimate_block_tokens via nameref
    local -a block_vars

    case "$stage" in
        coder)
            # shellcheck disable=SC2034
            block_vars=("ARCHITECTURE_BLOCK" "GLOSSARY_BLOCK" "MILESTONE_BLOCK" "HUMAN_NOTES_BLOCK" "PRIOR_REVIEWER_CONTEXT" "PRIOR_PROGRESS_CONTEXT" "PRIOR_TESTER_CONTEXT" "NON_BLOCKING_CONTEXT" "BUG_SCOUT_CONTEXT")
            ;;
        review)
            # shellcheck disable=SC2034
            block_vars=("ARCHITECTURE_CONTENT")
            ;;
        tester)
            # shellcheck disable=SC2034
            block_vars=("ARCHITECTURE_CONTENT")
            ;;
        *)
            return
            ;;
    esac

    local cpt="${CHARS_PER_TOKEN:-4}"
    local total_tokens
    total_tokens=$(_estimate_block_tokens block_vars)

    if check_context_budget "$total_tokens" "$model"; then
        return  # Under budget — no compression needed
    fi

    log "[context-compiler] Over budget (${total_tokens} est. tokens) — applying compression"

    # Compress in priority order: tester context, non-blocking, progress
    local -a compress_priority=("PRIOR_TESTER_CONTEXT" "NON_BLOCKING_CONTEXT" "PRIOR_PROGRESS_CONTEXT")

    for var_name in "${compress_priority[@]}"; do
        local val="${!var_name:-}"
        if [[ -z "$val" ]]; then
            continue
        fi

        local orig_chars=${#val}
        local compressed
        compressed=$(compress_context "$val" "truncate" 50)

        local new_chars=${#compressed}
        local saved=$(( orig_chars - new_chars ))
        if [[ "$saved" -gt 0 ]]; then
            log "[context-compiler] Compressed ${var_name}: saved ~$(( saved / cpt )) tokens"
            # Inject compression note
            local compressed_with_note
            compressed_with_note="[Context compressed: ${var_name} reduced from $(echo "$val" | count_lines) to $(echo "$compressed" | count_lines) lines]
${compressed}"
            export "$var_name=$compressed_with_note"
        fi

        # Re-check budget
        total_tokens=$(_estimate_block_tokens block_vars)

        if check_context_budget "$total_tokens" "$model"; then
            log "[context-compiler] Under budget after compressing ${var_name}"
            return
        fi
    done

    warn "[context-compiler] Still over budget after compression (${total_tokens} est. tokens)"
}
