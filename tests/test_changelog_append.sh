#!/usr/bin/env bash
# Test: Milestone 77 — changelog_assemble_entry + changelog_append
set -euo pipefail

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0

pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*"; FAIL=$((FAIL + 1)); }

TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

log() { :; }; warn() { :; }; error() { :; }; success() { :; }; header() { :; }

# shellcheck source=../lib/changelog.sh
source "${TEKHTON_HOME}/lib/changelog.sh"

make_changelog() {
    local dir="$1"; mkdir -p "$dir"
    cat > "$dir/CHANGELOG.md" <<'EOF'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
EOF
}

make_changelog_with_prior() {
    local dir="$1"; mkdir -p "$dir"
    cat > "$dir/CHANGELOG.md" <<'EOF'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-01-01

### Added
- Initial release
EOF
}

write_summary() { local d="$1"; shift; mkdir -p "$d"; printf '%s\n' "$@" > "$d/CODER_SUMMARY.md"; }

# --- commit type mapping ---
echo "=== mapping: commit types ==="
for pair in "feat:Added" "fix:Fixed" "refactor:Changed" "perf:Changed" \
            "security:Security" "deprecate:Deprecated" "remove:Removed" \
            "docs:" "chore:" "test:"; do
    type="${pair%%:*}"; expected="${pair#*:}"
    actual=$(_changelog_map_commit_type "$type")
    if [[ "$actual" == "$expected" ]]; then pass "map $type → $expected"
    else fail "map $type → expected '$expected' got '$actual'"; fi
done

# --- first entry under Unreleased ---
echo "=== append: first entry ==="
PROJ="${TEST_TMPDIR}/fresh"; make_changelog "$PROJ"
entry="## [1.2.3] - 2026-04-13

### Added
- New feature (M77)"
CHANGELOG_FILE=CHANGELOG.md changelog_append "$PROJ" "1.2.3" "$entry"
grep -q '## \[1\.2\.3\]' "$PROJ/CHANGELOG.md" && pass "version header" || fail "no version header"
grep -q 'New feature (M77)' "$PROJ/CHANGELOG.md" && pass "bullet" || fail "no bullet"
first=$(grep '^## \[' "$PROJ/CHANGELOG.md" | head -1)
[[ "$first" == *"Unreleased"* ]] && pass "[Unreleased] first" || fail "Unreleased not first: $first"

# --- new entry above prior release ---
echo "=== append: above prior ==="
PROJ="${TEST_TMPDIR}/prior"; make_changelog_with_prior "$PROJ"
entry="## [1.1.0] - 2026-04-13

### Fixed
- Bug fix (M99)"
CHANGELOG_FILE=CHANGELOG.md changelog_append "$PROJ" "1.1.0" "$entry"
sections=$(grep '^## \[' "$PROJ/CHANGELOG.md")
[[ "$(echo "$sections" | sed -n '1p')" == *"Unreleased"* ]] && pass "order: Unreleased" || fail "order1"
[[ "$(echo "$sections" | sed -n '2p')" == *"1.1.0"* ]] && pass "order: 1.1.0" || fail "order2"
[[ "$(echo "$sections" | sed -n '3p')" == *"1.0.0"* ]] && pass "order: 1.0.0" || fail "order3"
grep -q 'Initial release' "$PROJ/CHANGELOG.md" && pass "original preserved" || fail "original lost"

# --- idempotent re-run ---
echo "=== append: idempotent ==="
PROJ="${TEST_TMPDIR}/idem"; make_changelog "$PROJ"
entry1="## [2.0.0] - 2026-04-13

### Added
- First feature"
CHANGELOG_FILE=CHANGELOG.md changelog_append "$PROJ" "2.0.0" "$entry1"
entry2="## [2.0.0] - 2026-04-13

### Added
- Second feature"
CHANGELOG_FILE=CHANGELOG.md changelog_append "$PROJ" "2.0.0" "$entry2"
count=$(grep -c '## \[2\.0\.0\]' "$PROJ/CHANGELOG.md" || true)
[[ "$count" -eq 1 ]] && pass "no dup header" || fail "dup: expected 1, got $count"
grep -q 'First feature' "$PROJ/CHANGELOG.md" && pass "orig bullets" || fail "orig lost"
grep -q 'Second feature' "$PROJ/CHANGELOG.md" && pass "new bullets" || fail "new missing"

# --- assemble from coder summary ---
echo "=== assemble: coder summary ==="
PROJ="${TEST_TMPDIR}/asm_coder"
write_summary "$PROJ" "# Coder Summary" "## Status: COMPLETE" \
    "## What Was Implemented" "- Added changelog generation at finalize"
entry=$(changelog_assemble_entry "3.77.0" "77" "feat" "$PROJ/CODER_SUMMARY.md")
echo "$entry" | grep -q '## \[3\.77\.0\]' && pass "version" || fail "no version"
echo "$entry" | grep -q '### Added' && pass "Added section" || fail "not Added"
echo "$entry" | grep -q 'changelog generation' && pass "coder bullet" || fail "no bullet: $entry"
echo "$entry" | grep -q '(M77)' && pass "milestone tag" || fail "no tag"

# --- breaking changes ---
echo "=== assemble: breaking ==="
PROJ="${TEST_TMPDIR}/asm_break"
write_summary "$PROJ" "# Coder Summary" "## What Was Implemented" "- Changed API" \
    "## Breaking Changes" "- Removed /v1/users endpoint"
entry=$(changelog_assemble_entry "4.0.0" "80" "feat" "$PROJ/CODER_SUMMARY.md")
echo "$entry" | grep -q 'BREAKING' && pass "breaking bullet" || fail "no breaking: $entry"

# --- new public surface ---
echo "=== assemble: public surface ==="
PROJ="${TEST_TMPDIR}/asm_surface"
write_summary "$PROJ" "# Coder Summary" "## What Was Implemented" "- Added new feature" \
    "## New Public Surface" "- CHANGELOG_ENABLED config var"
entry=$(changelog_assemble_entry "3.77.0" "77" "feat" "$PROJ/CODER_SUMMARY.md")
echo "$entry" | grep -q 'CHANGELOG_ENABLED' && pass "surface bullet" || fail "no surface: $entry"

# --- skip docs/chore/test ---
echo "=== assemble: skip types ==="
for skip_type in docs chore test; do
    if changelog_assemble_entry "1.0.0" "" "$skip_type" "" 2>/dev/null; then
        fail "$skip_type not skipped"
    else
        pass "$skip_type skipped"
    fi
done

# --- milestone title fallback ---
echo "=== assemble: milestone fallback ==="
PROJ="${TEST_TMPDIR}/asm_fallback"
mkdir -p "$PROJ/.claude/milestones"
printf '%s\n' "# Tekhton Milestone Manifest v1" \
    "# id|title|status|depends_on|file|parallel_group" \
    "m77|CHANGELOG Generation at Finalize|done|m76|m77.md|runtime" \
    > "$PROJ/.claude/milestones/MANIFEST.cfg"
entry=$(PROJECT_DIR="$PROJ" MILESTONE_DIR=".claude/milestones" \
    MILESTONE_MANIFEST="MANIFEST.cfg" changelog_assemble_entry "3.77.0" "77" "feat" "")
echo "$entry" | grep -q 'CHANGELOG Generation' && pass "fallback title" || fail "no title: $entry"

# --- auto-create on append ---
echo "=== append: auto-create ==="
PROJ="${TEST_TMPDIR}/auto"; mkdir -p "$PROJ"
entry="## [1.0.0] - 2026-04-13

### Added
- Something new"
CHANGELOG_ENABLED=true CHANGELOG_FILE=CHANGELOG.md CHANGELOG_INIT_IF_MISSING=true \
    changelog_append "$PROJ" "1.0.0" "$entry"
[[ -f "$PROJ/CHANGELOG.md" ]] && pass "auto-created" || fail "not created"
grep -q 'Something new' "$PROJ/CHANGELOG.md" && pass "entry present" || fail "entry missing"

# --- fix → Fixed ---
echo "=== assemble: fix → Fixed ==="
PROJ="${TEST_TMPDIR}/asm_fix"
write_summary "$PROJ" "# Coder Summary" "## What Was Implemented" "- Fixed buffer overflow"
entry=$(changelog_assemble_entry "1.0.1" "" "fix" "$PROJ/CODER_SUMMARY.md")
echo "$entry" | grep -q '### Fixed' && pass "fix → Fixed" || fail "not Fixed: $entry"

# --- summary ---
echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -gt 0 ]] && exit 1 || exit 0
