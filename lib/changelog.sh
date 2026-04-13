#!/usr/bin/env bash
set -euo pipefail
# =============================================================================
# changelog.sh — CHANGELOG.md generation and management (Milestone 77)
#
# Sourced by tekhton.sh — do not run directly.
# Expects: lib/project_version.sh, lib/project_version_bump.sh, lib/hooks.sh
#          sourced first.
# Sources: lib/changelog_helpers.sh (bullet extraction + file manipulation)
# Provides:
#   changelog_init_if_missing   — create CHANGELOG.md stub when absent
#   changelog_assemble_entry    — build a keep-a-changelog entry (stdout)
#   changelog_append            — insert entry into CHANGELOG.md
#   _changelog_map_commit_type  — commit type → changelog section
#   _hook_changelog_append      — finalize hook
# =============================================================================

# shellcheck source=lib/changelog_helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/changelog_helpers.sh"

# --- Canonical CHANGELOG.md stub header --------------------------------------

_CHANGELOG_HEADER='# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]'

# --- Public API ---------------------------------------------------------------

# changelog_init_if_missing PROJECT_DIR
#   Creates CHANGELOG.md with the canonical header if the file does not exist.
#   Respects CHANGELOG_ENABLED and CHANGELOG_INIT_IF_MISSING config vars.
changelog_init_if_missing() {
    local project_dir="${1:-.}"
    [[ "${CHANGELOG_ENABLED:-true}" != "true" ]] && return 0
    [[ "${CHANGELOG_INIT_IF_MISSING:-true}" != "true" ]] && return 0

    local changelog_path="${project_dir}/${CHANGELOG_FILE:-CHANGELOG.md}"
    [[ -f "$changelog_path" ]] && return 0

    echo "$_CHANGELOG_HEADER" > "$changelog_path"
    if command -v log &>/dev/null; then
        log "Created ${CHANGELOG_FILE:-CHANGELOG.md} (keep-a-changelog format)"
    fi
}

# changelog_assemble_entry VERSION MILESTONE_ID COMMIT_TYPE CODER_SUMMARY_PATH
#   Assembles a keep-a-changelog entry and emits it to stdout.
#   Returns 1 if the commit type should be skipped (docs/chore/test).
changelog_assemble_entry() {
    local version="$1"
    local milestone_id="$2"
    local commit_type="$3"
    local summary_path="${4:-}"

    # Map commit type to changelog section; skip docs/chore/test
    local section
    section=$(_changelog_map_commit_type "$commit_type")
    [[ -z "$section" ]] && return 1

    # Collect bullets from multiple sources
    local bullets=""

    # Source 1: Breaking Changes subsection
    if [[ -n "$summary_path" ]] && [[ -f "$summary_path" ]]; then
        local breaking
        breaking=$(_changelog_extract_breaking "$summary_path")
        if [[ -n "$breaking" ]]; then
            bullets="${bullets}${breaking}"
        fi
    fi

    # Source 2: New Public Surface subsection
    if [[ -n "$summary_path" ]] && [[ -f "$summary_path" ]]; then
        local new_surface
        new_surface=$(_changelog_extract_new_surface "$summary_path")
        if [[ -n "$new_surface" ]]; then
            bullets="${bullets:+${bullets}$'\n'}${new_surface}"
        fi
    fi

    # Source 3: First non-empty paragraph of CODER_SUMMARY (if no bullets yet)
    if [[ -z "$bullets" ]] && [[ -n "$summary_path" ]] && [[ -f "$summary_path" ]]; then
        local coder_bullet
        coder_bullet=$(_changelog_extract_coder_bullet "$summary_path")
        if [[ -n "$coder_bullet" ]]; then
            bullets="$coder_bullet"
        fi
    fi

    # Source 4: Milestone title from MANIFEST.cfg (fallback)
    if [[ -z "$bullets" ]] && [[ -n "$milestone_id" ]]; then
        local ms_title
        ms_title=$(_changelog_get_milestone_title "$milestone_id")
        if [[ -n "$ms_title" ]]; then
            bullets="- ${ms_title} (M${milestone_id})"
        fi
    fi

    # Source 5: Commit message first line (last resort)
    if [[ -z "$bullets" ]]; then
        local first_line
        first_line=$(git log -1 --format='%s' 2>/dev/null || true)
        if [[ -n "$first_line" ]]; then
            # Strip conventional commit prefix (regex — sed needed for pattern)
            # shellcheck disable=SC2001
            first_line=$(echo "$first_line" | sed 's/^[a-z]*: //')
            bullets="- ${first_line}"
        fi
    fi

    # Still empty — give up
    [[ -z "$bullets" ]] && return 1

    # Add milestone tag to bullets that don't already have one
    if [[ -n "$milestone_id" ]]; then
        bullets=$(_changelog_tag_bullets "$bullets" "$milestone_id")
    fi

    # Build entry
    local date_str
    date_str=$(date +%Y-%m-%d)

    printf '## [%s] - %s\n\n### %s\n%s\n' "$version" "$date_str" "$section" "$bullets"
}

# changelog_append PROJECT_DIR VERSION ENTRY_CONTENT
#   Inserts entry into CHANGELOG.md between [Unreleased] and the previous
#   release. If a section for VERSION already exists, appends bullets to it
#   (idempotency — Decision #7).
changelog_append() {
    local project_dir="${1:-.}"
    local version="$2"
    local entry="$3"

    local changelog_path="${project_dir}/${CHANGELOG_FILE:-CHANGELOG.md}"

    # Auto-create if missing
    if [[ ! -f "$changelog_path" ]]; then
        changelog_init_if_missing "$project_dir"
    fi
    [[ ! -f "$changelog_path" ]] && return 1

    # Idempotency: check if this version already has a section
    local escaped_version
    escaped_version=$(printf '%s' "$version" | sed 's/\./\\./g')
    if grep -q "^## \\[${escaped_version}\\]" -- "$changelog_path" 2>/dev/null; then
        _changelog_append_to_existing "$changelog_path" "$version" "$entry"
        return 0
    fi

    # Insert after ## [Unreleased] line
    _changelog_insert_after_unreleased "$changelog_path" "$entry"
}

# --- Finalize hook -----------------------------------------------------------

# _hook_changelog_append — Append changelog entry on successful commit.
# Runs AFTER _hook_project_version_bump (knows new version) and BEFORE
# _hook_commit (entry included in the commit).
_hook_changelog_append() {
    local exit_code="$1"
    [[ "$exit_code" -ne 0 ]] && return 0
    [[ "${FINAL_CHECK_RESULT:-0}" -ne 0 ]] && return 0
    [[ "${CHANGELOG_ENABLED:-true}" != "true" ]] && return 0

    # Decision #6: skip if no changes to commit (zero-diff run)
    if [[ -z "$(git status --porcelain 2>/dev/null)" ]]; then
        return 0
    fi

    local project_dir="${PROJECT_DIR:-.}"

    # Read current version (already bumped by M76 hook)
    local version
    version=$(parse_current_version 2>/dev/null || echo "")
    [[ -z "$version" ]] && return 0

    # Determine commit type via shared helper from hooks.sh
    local commit_type
    commit_type=$(_infer_commit_type "${TASK:-}")

    # Skip docs/chore/test — no changelog for non-user-facing changes
    local section
    section=$(_changelog_map_commit_type "$commit_type")
    [[ -z "$section" ]] && return 0

    # Milestone ID
    local ms_id="${_CURRENT_MILESTONE:-}"

    # Coder summary path
    local summary_path="${project_dir}/${CODER_SUMMARY_FILE:-${TEKHTON_DIR:-.tekhton}/CODER_SUMMARY.md}"

    # Assemble entry
    local entry
    entry=$(changelog_assemble_entry "$version" "$ms_id" "$commit_type" "$summary_path") || return 0

    # Append to CHANGELOG.md
    changelog_append "$project_dir" "$version" "$entry"

    if command -v log &>/dev/null; then
        log "Appended changelog entry for v${version}"
    fi
}

# --- Commit type → changelog section mapping ----------------------------------

# _changelog_map_commit_type TYPE → section name or empty (skip)
_changelog_map_commit_type() {
    local commit_type="$1"
    case "$commit_type" in
        feat)      echo "Added" ;;
        fix)       echo "Fixed" ;;
        refactor)  echo "Changed" ;;
        perf)      echo "Changed" ;;
        security)  echo "Security" ;;
        deprecate) echo "Deprecated" ;;
        remove)    echo "Removed" ;;
        docs|chore|test) echo "" ;;  # skip
        *)         echo "Changed" ;;
    esac
}
