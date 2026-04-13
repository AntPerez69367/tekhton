# Coder Summary

## Status: COMPLETE

## What Was Implemented

Addressed all 10 open non-blocking notes in NON_BLOCKING_LOG.md:

1. **brew-bump.yml script injection (MEDIUM):** Moved `${{ steps.sha.outputs.tag }}` and `${{ steps.sha.outputs.sha256 }}` from inline `run:` interpolation to step-level `env:` vars (`TAG`, `TARBALL_SHA`). Both the "Update formula" and "Commit and push" steps now reference shell vars instead of expression contexts.

2. **brew-bump.yml unpinned checkout (MEDIUM):** Pinned `actions/checkout@v4` to full commit SHA `34e114876b0b11c390a56381ad16ebd13914f8d5` with a `# v4` comment for traceability.

3. **brew-bump.yml missing permissions (MEDIUM):** Added `permissions: contents: read` at workflow level.

4. **installation.md mutable curl|bash URL (LOW):** Added a "pinned install" section showing how to use a versioned release tag URL alongside the existing `main` branch one-liner.

5. **changelog_helpers.sh double blank line:** Updated `_changelog_insert_after_unreleased` to check whether the line after `## [Unreleased]` is already blank before inserting a separator line. Avoids double blank lines in CHANGELOG.md files that already have a blank line after the header.

6. **prompts.sh CHANGELOG_* template vars:** Confirmed these vars are not referenced by any prompt template — no code change needed. Marked as resolved (correct to skip).

7. **test_project_version_detect.sh pubspec assertion:** Tightened `grep -q 'CURRENT_VERSION=1.0.0'` to `grep -qE 'CURRENT_VERSION=1\.0\.0\+1$'` so the test matches the actual detected value (`1.0.0+1` from `version: 1.0.0+1` in pubspec.yaml) and won't false-pass on a hypothetical `1.0.0` without the build number.

8. **project_version.sh vestigial path_key:** Added a comment at the ecosystems array explaining that `path_key` is stored in `VERSION_FILES` but not consumed by bump logic, and is reserved for a future structured-read accessor.

9. **finalize_version.sh unused exit_code:** Added a comment explaining why `exit_code` is deliberately not checked — the tagging hook guards on `_COMMIT_SUCCEEDED` (set by `_hook_commit`) rather than pipeline exit code, because tags should only be created after a confirmed git commit.

10. **docs_agent.sh / docs.sh sed duplication:** Extracted the duplicated `sed` range expression into a new shared function `_docs_extract_doc_responsibilities()` in `lib/docs_agent.sh`. Both `_docs_extract_public_surface()` and `_docs_prepare_template_vars()` now call this helper.

## Root Cause (bugs only)

N/A — tech debt cleanup, not a bug fix.

## Files Modified

- `.github/workflows/brew-bump.yml` — security hardening (env vars, SHA pin, permissions)
- `docs/getting-started/installation.md` — added versioned install URL
- `lib/changelog_helpers.sh` — fixed double blank line in `_changelog_insert_after_unreleased`
- `lib/project_version.sh` — added comment about vestigial path_key
- `lib/finalize_version.sh` — added comment about unused exit_code
- `lib/docs_agent.sh` — extracted `_docs_extract_doc_responsibilities()` shared helper
- `stages/docs.sh` — uses new shared helper instead of inline sed
- `tests/test_project_version_detect.sh` — tightened pubspec.yaml assertion
- `NON_BLOCKING_LOG.md` — moved all 10 items from Open to Resolved

## Docs Updated

- `docs/getting-started/installation.md` — added versioned tag URL install option

## Human Notes Status

N/A — no human notes in this task.
