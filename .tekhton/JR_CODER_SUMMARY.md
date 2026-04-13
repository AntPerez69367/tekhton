## What Was Fixed

- Added missing `set -euo pipefail` safety directive to `lib/changelog.sh` (line 2, after shebang)
- Added missing `set -euo pipefail` safety directive to `lib/changelog_helpers.sh` (line 2, after shebang)

Both files now conform to the project's non-negotiable safety requirement per CLAUDE.md §2.

## Files Modified

- `lib/changelog.sh`
- `lib/changelog_helpers.sh`

## Verification

- ✓ shellcheck: clean
- ✓ bash -n: syntax valid
