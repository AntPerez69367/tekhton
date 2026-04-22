#!/usr/bin/env bash
set -euo pipefail

TEKHTON_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS=0
FAIL=0

pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*"; FAIL=$((FAIL + 1)); }

TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

cp "$TEKHTON_HOME/tekhton.sh" "$TEST_TMPDIR/tekhton.sh"
cp "$TEKHTON_HOME/VERSION" "$TEST_TMPDIR/VERSION"

echo "9.42.7" > "$TEST_TMPDIR/VERSION"

output=$(cd "$TEST_TMPDIR" && bash ./tekhton.sh --version)
if [[ "$output" == "Tekhton 9.42.7" ]]; then
    pass "--version reads VERSION file instead of a hardcoded constant"
else
    fail "--version returned '$output'"
fi

echo
echo "Results: ${PASS} passed, ${FAIL} failed"

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
