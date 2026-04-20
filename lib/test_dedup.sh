#!/usr/bin/env bash
# =============================================================================
# test_dedup.sh — Test run deduplication via working-tree fingerprinting (M105)
#
# Skips redundant TEST_CMD executions when the working tree is byte-identical to
# the state captured during the last successful test pass. A fingerprint change
# (modified/staged/untracked/deleted files, or a TEST_CMD config change)
# invalidates the cache, forcing a re-run.
#
# Sourced by tekhton.sh after gates_completion.sh — do not run directly.
# Expects: TEKHTON_DIR, TEST_CMD, TEST_DEDUP_ENABLED (from config).
#
# Provides:
#   _test_dedup_fingerprint — compute hash of working-tree state + TEST_CMD
#   test_dedup_record_pass  — cache the current fingerprint as "last passing"
#   test_dedup_can_skip     — return 0 if the cached fingerprint matches now
#   test_dedup_reset        — clear the cached fingerprint
# =============================================================================

# _test_dedup_fingerprint
# Emits a stable hash of the working-tree state plus the active TEST_CMD.
# In a non-git directory (or if git fails), emits a unique value per call so
# callers can never match a previous fingerprint — dedup degrades gracefully
# to "always re-run".
_test_dedup_fingerprint() {
    if command -v git &>/dev/null \
       && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
        # git status --porcelain covers modified, staged, untracked, deleted.
        # Including TEST_CMD ensures a config change invalidates the cache.
        { git status --porcelain 2>/dev/null; echo "cmd:${TEST_CMD:-}"; } \
            | md5sum | cut -d' ' -f1
    else
        echo "no-git-$(date +%s%N)"
    fi
}

# _test_dedup_fingerprint_file
# Resolves the on-disk path used to persist the "last passing" fingerprint.
_test_dedup_fingerprint_file() {
    echo "${TEKHTON_DIR:-.tekhton}/test_dedup.fingerprint"
}

# test_dedup_record_pass
# Caches the current fingerprint so the next test invocation with an identical
# working tree can skip. No-op when TEST_DEDUP_ENABLED is not "true".
test_dedup_record_pass() {
    [[ "${TEST_DEDUP_ENABLED:-true}" = "true" ]] || return 0
    local fp_file
    fp_file=$(_test_dedup_fingerprint_file)
    local fp
    fp=$(_test_dedup_fingerprint)
    mkdir -p "$(dirname "$fp_file")" 2>/dev/null || true
    printf '%s\n' "$fp" > "$fp_file"
}

# test_dedup_can_skip
# Returns 0 (skip tests) when the current fingerprint matches the cached
# "last passing" fingerprint. Returns 1 (must run) otherwise — including when
# dedup is disabled, no fingerprint is cached, or git is unavailable.
test_dedup_can_skip() {
    [[ "${TEST_DEDUP_ENABLED:-true}" = "true" ]] || return 1
    local fp_file
    fp_file=$(_test_dedup_fingerprint_file)
    [[ -f "$fp_file" ]] || return 1
    local current previous
    current=$(_test_dedup_fingerprint)
    previous=$(cat "$fp_file" 2>/dev/null || echo "")
    [[ -n "$previous" ]] || return 1
    [[ "$current" = "$previous" ]]
}

# test_dedup_reset
# Removes the cached fingerprint. Called once at pipeline start so stale state
# from a previous run never leaks into a new run.
test_dedup_reset() {
    local fp_file
    fp_file=$(_test_dedup_fingerprint_file)
    rm -f "$fp_file" 2>/dev/null || true
}
