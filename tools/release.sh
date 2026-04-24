#!/usr/bin/env bash
# =============================================================================
# release.sh — Tekhton release helper with prepare + post-merge modes
#
# Modes:
#   prepare              Sync drift-prone version references from VERSION and
#                        print a release checklist.
#   post-merge           Create/push tag + create GitHub Release.
#
# Source of truth:
#   VERSION (root file, plain MAJOR.MINOR.PATCH)
# =============================================================================

set -euo pipefail

MODE="${1:-}"
ARG_VERSION="${2:-}"
COMMIT="${3:-HEAD}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NOTES_DIR="$REPO_ROOT/tools/release_notes"
VERSION_FILE="$REPO_ROOT/VERSION"
README_FILE="$REPO_ROOT/README.md"

err()  { printf '\033[1;31m[✗]\033[0m %s\n' "$*" >&2; exit 1; }
ok()   { printf '\033[1;32m[✓]\033[0m %s\n' "$*"; }
info() { printf '\033[1;36m[i]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }

usage() {
    cat <<'EOF'
Usage:
  tools/release.sh prepare [vX.Y.Z] [commit]
  tools/release.sh post-merge [vX.Y.Z] [commit]

Legacy (still supported):
  tools/release.sh vX.Y.Z [commit]        # equivalent to post-merge

Notes:
  - VERSION file is the source of truth (X.Y.Z, no leading v)
  - Optional vX.Y.Z argument must match VERSION exactly if provided
  - Release notes must exist at tools/release_notes/vX.Y.Z.md
EOF
    exit 1
}

read_version_tag_from_file() {
    [[ -f "$VERSION_FILE" ]] || err "VERSION file missing: $VERSION_FILE"
    local raw
    raw="$(tr -d '[:space:]' < "$VERSION_FILE")"
    [[ "$raw" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
        err "VERSION must be MAJOR.MINOR.PATCH (got: $raw)"
    }
    printf 'v%s\n' "$raw"
}

resolve_version_tag() {
    local from_file
    from_file="$(read_version_tag_from_file)"

    if [[ -z "$ARG_VERSION" ]]; then
        printf '%s\n' "$from_file"
        return 0
    fi

    [[ "$ARG_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
        err "Version must match vMAJOR.MINOR.PATCH (got: $ARG_VERSION)"
    }

    [[ "$ARG_VERSION" == "$from_file" ]] || {
        err "Version mismatch: VERSION file is $from_file but argument is $ARG_VERSION"
    }

    printf '%s\n' "$from_file"
}

sync_readme_header_version() {
    local version_tag="$1"
    [[ -f "$README_FILE" ]] || err "README not found: $README_FILE"

    local before
    before="$(grep -nE '<p><em>v[0-9]+\.[0-9]+\.[0-9]+ — ' "$README_FILE" || true)"
    if [[ -z "$before" ]]; then
        warn "README hero version line not found; skipping README sync."
        return 0
    fi

    local tmp
    tmp="$(mktemp)"
    sed -E "s#(<p><em>)v[0-9]+\.[0-9]+\.[0-9]+( — )#\\1${version_tag}\\2#" "$README_FILE" > "$tmp"
    mv "$tmp" "$README_FILE"

    local after
    after="$(grep -nE "<p><em>${version_tag} — " "$README_FILE" || true)"
    [[ -n "$after" ]] || err "Failed to sync README hero version to $version_tag"

    ok "Synced README hero version to $version_tag"
}

release_notes_path() {
    local version_tag="$1"
    printf '%s/%s.md\n' "$NOTES_DIR" "$version_tag"
}

ensure_commit_exists() {
    local commit_ref="$1"
    if ! git rev-parse --verify "$commit_ref" >/dev/null 2>&1; then
        err "Commit not found: $commit_ref"
    fi
}

run_prepare() {
    local version_tag
    version_tag="$(resolve_version_tag)"

    cd "$REPO_ROOT"
    sync_readme_header_version "$version_tag"

    local notes_file
    notes_file="$(release_notes_path "$version_tag")"

    echo
    info "Prepare-release checklist for ${version_tag}:"
    printf '  1. Confirm VERSION is correct (%s).\n' "$version_tag"
    printf '  2. Ensure README/docs changes are committed (README was synced).\n'

    if [[ -f "$notes_file" ]]; then
        printf '  3. Release notes exists: %s\n' "$notes_file"
    else
        warn "Release notes missing: $notes_file"
        printf '  3. Create release notes before post-merge. Starter:\n'
        printf '     mkdir -p tools/release_notes && cat > %s <<\'"'"'EOF\'"'"'\n' "$notes_file"
        printf '## <release title> (%s)\n\n- Summary bullet 1\n- Summary bullet 2\n\n## Impact\n- ...\nEOF\n' "$version_tag"
    fi

    printf '  4. Merge to main.\n'
    printf '  5. After merge, run: tools/release.sh post-merge %s\n' "$version_tag"
    echo

    if [[ ! -f "$notes_file" ]]; then
        err "Prepare step blocked until release notes file exists."
    fi

    ok "Prepare step complete."
}

run_post_merge() {
    local version_tag
    version_tag="$(resolve_version_tag)"

    cd "$REPO_ROOT"

    ensure_commit_exists "$COMMIT"
    local commit_sha commit_short commit_subject
    commit_sha="$(git rev-parse "$COMMIT")"
    commit_short="$(git rev-parse --short "$COMMIT")"
    commit_subject="$(git log -1 --format=%s "$COMMIT")"

    if git rev-parse --verify "refs/tags/$version_tag" >/dev/null 2>&1; then
        err "Tag $version_tag already exists locally. Delete it first: git tag -d $version_tag"
    fi
    if git ls-remote --tags origin "$version_tag" 2>/dev/null | grep -q "$version_tag"; then
        err "Tag $version_tag already exists on origin. Aborting to avoid overwriting."
    fi

    local notes_file
    notes_file="$(release_notes_path "$version_tag")"
    [[ -f "$notes_file" ]] || err "Release notes file not found: $notes_file"

    local notes_lines
    notes_lines="$(wc -l < "$notes_file" | tr -d ' ')"
    if [[ "$notes_lines" -lt 5 ]]; then
        warn "Release notes file is only $notes_lines lines. Continue? (Ctrl+C to abort)"
        read -r _
    fi

    info "Release plan:"
    printf '  Version:    %s\n' "$version_tag"
    printf '  Commit:     %s (%s)\n' "$commit_short" "$commit_sha"
    printf '  Subject:    %s\n' "$commit_subject"
    printf '  Notes:      %s (%s lines)\n' "$notes_file" "$notes_lines"
    echo
    read -r -p "Proceed with release? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || {
        info "Aborted."
        exit 0
    }

    info "Creating annotated tag $version_tag at $commit_short..."
    local tag_message
    tag_message="$(printf 'Tekhton %s\n\n' "$version_tag"; cat "$notes_file")"
    git tag -a "$version_tag" "$commit_sha" -m "$tag_message"
    ok "Tag created locally."

    info "Pushing tag to origin..."
    if ! git push origin "$version_tag"; then
        warn "Push failed. The tag exists locally; you can retry with:"
        printf '    git push origin %s\n' "$version_tag"
        exit 1
    fi
    ok "Tag pushed to origin."

    if command -v gh >/dev/null 2>&1; then
        info "Creating GitHub Release via gh CLI..."

        if gh release create "$version_tag" \
            --title "$version_tag — $(head -1 "$notes_file" | sed 's/^#* *//')" \
            --notes-file "$notes_file"; then
            ok "GitHub Release created."
            gh release view "$version_tag" --web 2>/dev/null || true
        else
            warn "gh release create failed. Tag is pushed; create the release manually."
        fi
    else
        warn "gh CLI not found. Tag is pushed but the GitHub Release page must be created manually."
        local repo_url
        repo_url="$(git config --get remote.origin.url | sed -E 's#(git@|https?://)([^:/]+)[:/]([^/]+/[^.]+)(\.git)?#https://\2/\3#')"
        info "Open: ${repo_url}/releases/new?tag=$version_tag"
        info "Paste the body from: $notes_file"
    fi

    echo
    ok "Release $version_tag complete."
}

# Legacy mode: first arg is a version tag
if [[ "$MODE" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    ARG_VERSION="$MODE"
    MODE="post-merge"
fi

case "$MODE" in
    prepare)
        run_prepare
        ;;
    post-merge)
        run_post_merge
        ;;
    *)
        usage
        ;;
esac
