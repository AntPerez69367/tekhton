# Coder Summary
## Status: COMPLETE
## What Was Implemented
- Rewrote README.md Install section: curl|bash one-liner is now the headline install method, followed by Homebrew tap, then from-source as a secondary option
- Cleaned up Quick Start section: removed redundant install steps, assumes `tekhton` is on PATH from the new Install section
- Created `.github/workflows/brew-bump.yml`: tag-push triggered workflow that computes tarball sha256, updates the Homebrew tap formula, and runs a macOS smoke test verifying `brew install` works
- Created `docs/RELEASING.md`: maintainer runbook covering one-time tap repo setup, PAT configuration, release cut process, and troubleshooting (sha256 drift, formula rollback, expired tokens)
- Updated `docs/getting-started/installation.md`: added curl|bash one-liner and Homebrew as primary install methods ahead of the git clone path
- Bumped `TEKHTON_VERSION` to `3.78.0` in `tekhton.sh`
- Updated README version banner from v3.71.1 to v3.78.0

## Root Cause (bugs only)
N/A — docs + packaging milestone, no bug fix.

## Files Modified
- `README.md` — rewrote Install/Quick Start sections, updated version banner
- `tekhton.sh` — bumped TEKHTON_VERSION to 3.78.0
- `.github/workflows/brew-bump.yml` (NEW) — Homebrew formula auto-update workflow
- `docs/RELEASING.md` (NEW) — maintainer release runbook
- `docs/getting-started/installation.md` — added curl|bash and Homebrew install methods

## Human Notes Status
No human notes for this milestone.

## Docs Updated
- `README.md` — Install section rewritten with curl|bash headline, Homebrew, from-source, and platform notes
- `docs/getting-started/installation.md` — added curl|bash and Homebrew install methods
- `docs/RELEASING.md` (NEW) — maintainer release runbook
