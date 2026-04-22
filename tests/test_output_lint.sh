#!/usr/bin/env bash
set -euo pipefail
# =============================================================================
# test_output_lint.sh — Output-module lint check (M101 §5)
#
# Fails if any direct `echo -e "...${BOLD|RED|GREEN|YELLOW|CYAN|NC}..."` call
# exists in lib/ or stages/ outside the output module
# (lib/common.sh, lib/output.sh, lib/output_format.sh).
#
# Runs standalone: `bash tests/test_output_lint.sh` and as part of
# `tests/run_tests.sh`.
# =============================================================================

# Resolve repo root so the test is usable from any CWD.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
cd "$repo_root"

pattern='echo -e.*\${\(BOLD\|RED\|GREEN\|YELLOW\|CYAN\|NC\)}'
exclude='lib/common\.sh\|lib/output[^/]*\.sh'

matches=$(grep -rn "$pattern" lib/ stages/ --include="*.sh" 2>/dev/null \
    | grep -v "$exclude" \
    || true)

if [[ -n "$matches" ]]; then
    count=$(printf '%s\n' "$matches" | wc -l | tr -d '[:space:]')
    echo "FAIL: ${count} direct ANSI echo call(s) found outside output module:"
    printf '%s\n' "$matches"
    exit 1
fi

echo "PASS: No direct ANSI echo calls outside output module"
