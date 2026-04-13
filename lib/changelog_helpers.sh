#!/usr/bin/env bash
set -euo pipefail
# =============================================================================
# changelog_helpers.sh — Changelog bullet extraction and file manipulation
#
# Sourced by changelog.sh — do not run directly.
# Provides:
#   _changelog_extract_coder_bullet   — first bullet from CODER_SUMMARY
#   _changelog_extract_breaking       — Breaking Changes bullets
#   _changelog_extract_new_surface    — New Public Surface bullets
#   _changelog_get_milestone_title    — title from MANIFEST.cfg
#   _changelog_tag_bullets            — add (MNNN) tags
#   _changelog_insert_after_unreleased — file insertion
#   _changelog_append_to_existing     — idempotent section append
# =============================================================================

# _changelog_extract_coder_bullet FILE
#   Extracts the first non-empty paragraph from the ## What Was Implemented section.
_changelog_extract_coder_bullet() {
    local file="$1"
    [[ ! -f "$file" ]] && return 0

    local bullet
    bullet=$(awk '
        /^## What [Ww]as [Ii]mplemented/ { found=1; next }
        found && /^##/ { exit }
        found && NF {
            # Strip leading markdown bullet markers and ## headers
            gsub(/^#+\s*/, "")
            gsub(/^[-*] /, "")
            if (length($0) > 0) { print "- " $0; exit }
        }
    ' "$file" 2>/dev/null || true)
    echo "$bullet"
}

# _changelog_extract_breaking FILE
#   Extracts bullets from ## Breaking Changes subsection.
_changelog_extract_breaking() {
    local file="$1"
    [[ ! -f "$file" ]] && return 0

    awk '
        /^## Breaking Changes/ { found=1; next }
        found && /^##/ { exit }
        found && /^[-*] / {
            gsub(/^[-*] /, "")
            gsub(/^#+\s*/, "")
            print "- **BREAKING:** " $0
        }
    ' "$file" 2>/dev/null || true
}

# _changelog_extract_new_surface FILE
#   Extracts bullets from ## New Public Surface subsection.
_changelog_extract_new_surface() {
    local file="$1"
    [[ ! -f "$file" ]] && return 0

    awk '
        /^## New Public Surface/ { found=1; next }
        found && /^##/ { exit }
        found && /^[-*] / {
            gsub(/^[-*] /, "")
            gsub(/^#+\s*/, "")
            print "- " $0
        }
    ' "$file" 2>/dev/null || true
}

# _changelog_get_milestone_title ID
#   Reads the milestone title from MANIFEST.cfg.
_changelog_get_milestone_title() {
    local ms_id="$1"
    local manifest="${PROJECT_DIR:-.}/${MILESTONE_DIR:-.claude/milestones}/${MILESTONE_MANIFEST:-MANIFEST.cfg}"
    [[ ! -f "$manifest" ]] && return 0

    awk -F'|' -v id="m${ms_id}" '$1 == id { print $2; exit }' "$manifest" 2>/dev/null || true
}

# _changelog_tag_bullets BULLETS MILESTONE_ID
#   Appends (MNNN) to bullets that don't already have a milestone tag.
_changelog_tag_bullets() {
    local bullets="$1"
    local ms_id="$2"
    local tag="(M${ms_id})"

    echo "$bullets" | while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if echo "$line" | grep -qF "(M${ms_id})"; then
            echo "$line"
        else
            echo "${line} ${tag}"
        fi
    done
}

# _changelog_insert_after_unreleased FILE ENTRY
#   Inserts ENTRY after the ## [Unreleased] line with a blank line separator.
_changelog_insert_after_unreleased() {
    local file="$1"
    local entry="$2"

    # Find the line number of ## [Unreleased]
    local line_num
    line_num=$(grep -n '^\#\# \[Unreleased\]' -- "$file" 2>/dev/null | head -1 | cut -d: -f1)

    if [[ -z "$line_num" ]]; then
        # No [Unreleased] header — append at end
        printf '\n%s\n' "$entry" >> "$file"
        return 0
    fi

    # Insert after the [Unreleased] line, avoiding double blank lines.
    # Check if the line immediately after [Unreleased] is already blank.
    local next_line
    next_line=$(sed -n "$((line_num + 1))p" "$file")

    local tmpfile
    tmpfile=$(mktemp)
    {
        head -n "$line_num" "$file"
        if [[ -n "$next_line" ]]; then
            echo ""
        fi
        echo "$entry"
        tail -n +"$((line_num + 1))" "$file"
    } > "$tmpfile"
    mv "$tmpfile" "$file"
}

# _changelog_append_to_existing FILE VERSION ENTRY
#   Appends new bullets to an existing version section (idempotency).
_changelog_append_to_existing() {
    local file="$1"
    local version="$2"
    local entry="$3"

    # Extract only the bullet lines from the entry (lines starting with -)
    local new_bullets
    new_bullets=$(echo "$entry" | grep '^- ' || true)
    [[ -z "$new_bullets" ]] && return 0

    # Find the last line of the existing version's section (before next ## or EOF)
    local escaped_version
    escaped_version=$(printf '%s' "$version" | sed 's/\./\\./g')
    local section_start
    section_start=$(grep -n "^## \\[${escaped_version}\\]" -- "$file" 2>/dev/null | head -1 | cut -d: -f1)
    [[ -z "$section_start" ]] && return 0

    # Find the end of this section (next ## header or EOF)
    local total_lines
    total_lines=$(wc -l < "$file")
    local section_end="$total_lines"
    local next_header
    next_header=$(tail -n +"$((section_start + 1))" "$file" | grep -n '^## ' | head -1 | cut -d: -f1 || true)
    if [[ -n "$next_header" ]]; then
        section_end=$(( section_start + next_header - 1 ))
    fi

    # Insert new bullets before the section end
    local tmpfile
    tmpfile=$(mktemp)
    {
        head -n "$((section_end))" "$file"
        echo "$new_bullets"
        tail -n +"$((section_end + 1))" "$file"
    } > "$tmpfile"
    mv "$tmpfile" "$file"
}
