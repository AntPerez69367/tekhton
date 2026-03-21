#!/usr/bin/env bash
# Test: cleanup targeted revert — primary-pipeline file changes survive cleanup
# build-gate failure.  Only files introduced by the cleanup agent are reverted;
# files already modified by the primary pipeline are preserved.
set -euo pipefail

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# ── Helpers ─────────────────────────────────────────────────────────────────

FAIL=0

assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" != "$actual" ]; then
        echo "FAIL: $name — expected '$expected', got '$actual'"
        FAIL=1
    fi
}

assert_file_content() {
    local name="$1" file="$2" expected="$3"
    local actual
    actual=$(cat "$file" 2>/dev/null || true)
    if [ "$expected" != "$actual" ]; then
        echo "FAIL: $name — expected content '$expected', got '$actual'"
        FAIL=1
    fi
}

# ── Set up a real git repo in TMPDIR ────────────────────────────────────────

cd "$TMPDIR"
git init -q
git config user.email "test@test.com"
git config user.name "Test"

# Create and commit baseline files
echo "original-pipeline-file" > pipeline_file.txt
echo "original-cleanup-file"  > cleanup_file.txt
echo "original-untouched"     > untouched_file.txt
git add .
git commit -q -m "initial commit"

# =============================================================================
# Scenario: primary pipeline modifies pipeline_file.txt; cleanup modifies
# cleanup_file.txt. Cleanup build gate fails. Only cleanup_file.txt should
# be reverted. pipeline_file.txt retains the primary pipeline's changes.
# =============================================================================

# Simulate primary pipeline modifying pipeline_file.txt
echo "primary-pipeline-change" > pipeline_file.txt

# Capture the pre-cleanup snapshot (same logic as cleanup.sh line 77)
pre_cleanup_files=$(git diff --name-only 2>/dev/null || true)

# Verify pre-cleanup snapshot only contains pipeline_file.txt
EXPECTED_PRE="pipeline_file.txt"
assert_eq "pre_cleanup_files" "$EXPECTED_PRE" "$pre_cleanup_files"

# Simulate cleanup agent modifying cleanup_file.txt
echo "cleanup-agent-change" > cleanup_file.txt

# Build gate failure: capture post-cleanup changed files
post_cleanup_files=$(git diff --name-only 2>/dev/null || true)

# Verify post-cleanup snapshot contains both files
if ! echo "$post_cleanup_files" | grep -qxF "pipeline_file.txt"; then
    echo "FAIL: post_cleanup_files missing pipeline_file.txt"
    FAIL=1
fi
if ! echo "$post_cleanup_files" | grep -qxF "cleanup_file.txt"; then
    echo "FAIL: post_cleanup_files missing cleanup_file.txt"
    FAIL=1
fi

# ── Run the targeted revert logic (replicated from cleanup.sh lines 113-121) ─

if [ -n "$post_cleanup_files" ]; then
    while IFS= read -r changed_file; do
        [ -z "$changed_file" ] && continue
        # Only revert if this file was NOT already modified before cleanup
        if ! echo "$pre_cleanup_files" | grep -qxF "$changed_file" 2>/dev/null; then
            git checkout -- "$changed_file" 2>/dev/null || true
        fi
    done <<< "$post_cleanup_files"
fi

# ── Assertions ───────────────────────────────────────────────────────────────

# pipeline_file.txt: must still contain the primary pipeline's change (NOT reverted)
assert_file_content \
    "primary-pipeline change preserved" \
    "pipeline_file.txt" \
    "primary-pipeline-change"

# cleanup_file.txt: must be reverted to its committed state (cleanup change undone)
assert_file_content \
    "cleanup change reverted" \
    "cleanup_file.txt" \
    "original-cleanup-file"

# untouched_file.txt: unmodified throughout, must stay at baseline
assert_file_content \
    "untouched file unchanged" \
    "untouched_file.txt" \
    "original-untouched"

# After revert, only pipeline_file.txt should appear in git diff
remaining_modified=$(git diff --name-only 2>/dev/null || true)
assert_eq "only primary-pipeline file remains modified" "pipeline_file.txt" "$remaining_modified"

# =============================================================================
# Edge case: cleanup modifies NO files — revert loop is a no-op
# =============================================================================

# Reset state: commit the current pipeline change so we start fresh
git add pipeline_file.txt
git commit -q -m "apply pipeline change"

echo "second-pipeline-change" > pipeline_file.txt
pre_cleanup_files2=$(git diff --name-only 2>/dev/null || true)

# Cleanup makes no file changes — post == pre
post_cleanup_files2=$(git diff --name-only 2>/dev/null || true)

# Run revert logic (should be a no-op since pre == post)
if [ -n "$post_cleanup_files2" ]; then
    while IFS= read -r changed_file; do
        [ -z "$changed_file" ] && continue
        if ! echo "$pre_cleanup_files2" | grep -qxF "$changed_file" 2>/dev/null; then
            git checkout -- "$changed_file" 2>/dev/null || true
        fi
    done <<< "$post_cleanup_files2"
fi

# pipeline_file.txt must still contain the second pipeline change
assert_file_content \
    "no-op revert preserves pipeline file" \
    "pipeline_file.txt" \
    "second-pipeline-change"

# =============================================================================
# Edge case: cleanup modifies a file that was also modified by the primary
# pipeline (overlap). The file must NOT be reverted.
# =============================================================================

# Start from a clean committed state
git add pipeline_file.txt
git commit -q -m "apply second pipeline change"

echo "overlap-pipeline-change" > pipeline_file.txt
pre_cleanup_files3=$(git diff --name-only 2>/dev/null || true)

# Cleanup also touches the same file (overlap scenario)
echo "overlap-cleanup-change" > pipeline_file.txt
post_cleanup_files3=$(git diff --name-only 2>/dev/null || true)

if [ -n "$post_cleanup_files3" ]; then
    while IFS= read -r changed_file; do
        [ -z "$changed_file" ] && continue
        if ! echo "$pre_cleanup_files3" | grep -qxF "$changed_file" 2>/dev/null; then
            git checkout -- "$changed_file" 2>/dev/null || true
        fi
    done <<< "$post_cleanup_files3"
fi

# The file was in pre_cleanup_files, so it must NOT be reverted to baseline.
# It keeps whatever the cleanup agent wrote (overlap file is protected because
# the primary pipeline had already claimed it).
CURRENT_CONTENT=$(cat pipeline_file.txt 2>/dev/null || true)
if [ "$CURRENT_CONTENT" = "overlap-cleanup-change" ] || [ "$CURRENT_CONTENT" = "overlap-pipeline-change" ]; then
    : # either is acceptable — the file was not silently reset to baseline
else
    echo "FAIL: overlap file reverted to baseline unexpectedly: '$CURRENT_CONTENT'"
    FAIL=1
fi

# The important invariant: the file was NOT reverted to the original committed value
if [ "$CURRENT_CONTENT" = "second-pipeline-change" ]; then
    echo "FAIL: overlap file was reverted to pre-cleanup committed state"
    FAIL=1
fi

# =============================================================================

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
