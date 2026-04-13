# Reviewer Report

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- [.github/workflows/brew-bump.yml:30] Security agent flagged `${{ steps.sha.outputs.tag }}` interpolated inline into `sed` run command (script injection pattern, MEDIUM). The security agent marked this fixable — move into a step-level `env:` var and reference as `$TAG`.
- [.github/workflows/brew-bump.yml:20] Security agent flagged `actions/checkout@v4` as an unpinned mutable tag (MEDIUM). Pin to a full commit SHA per GitHub hardening guidance.
- [.github/workflows/brew-bump.yml] Security agent flagged missing `permissions` block (MEDIUM). Add `permissions: contents: read` at workflow level; the bump job needs no repo access beyond what the PAT provides.
- [docs/getting-started/installation.md:22] Security agent flagged the curl|bash one-liner fetching from mutable `main` branch (LOW). Consider documenting a versioned tag URL alongside the existing review step, or adding a sha256 checksum.

## Coverage Gaps
- None

## Drift Observations
- [.github/workflows/brew-bump.yml:50] Smoke-test job runs `brew install tekhton` (short form after explicit `brew tap`) while README and installation.md show the long form `brew install geoffgodwin/tekhton/tekhton`. Both are correct post-tap, but the inconsistency could confuse maintainers reading the workflow vs. docs.
- [docs/RELEASING.md:79] References `.github/workflows/release.yml` as creating "GitHub Release with a tarball and SHA256SUMS" — that workflow exists (M19 deliverable) and is accurate, but the runbook gives no indication of where to find or verify it. Minor discoverability gap for new maintainers.
