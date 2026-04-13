# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in ${REVIEWER_REPORT_FILE}.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-13 | "M77"] `_changelog_insert_after_unreleased` inserts a blank line before the entry regardless of whether the original file already had one after `## [Unreleased]`. May produce a double blank line in some CHANGELOG.md files. Cosmetic only.
- [ ] [2026-04-13 | "M77"] `lib/prompts.sh` was not updated with CHANGELOG_* template vars (listed in the spec's Step 1). These vars are not referenced by any prompt template, so registering them would be a no-op. Correct to skip.
- [ ] [2026-04-12 | "M76"] `tests/test_project_version_detect.sh:158` — The pubspec.yaml assertion `grep -q 'CURRENT_VERSION=1.0.0'` is a substring match and passes falsely when the config contains `CURRENT_VERSION=1.0.0+1` (Flutter build number is not stripped during detection). Tighten to `grep -qE 'CURRENT_VERSION=1.0.0$'` to distinguish the two cases. (Carried from cycle 1 — still unaddressed, no blocker.)
- [ ] [2026-04-12 | "M76"] `lib/project_version.sh:88-99` — `path_key` (e.g. `.version`, `.project.version`) is written into `VERSION_FILES` in the config cache but is never consumed by the bump logic — `_bump_single_file` re-derives the accessor from the filename via `_accessor_for_file`, ignoring the stored path entirely. The key is vestigial as shipped. Either remove it from `VERSION_FILES` or add a comment explaining it is reserved for a future structured-read accessor. (Carried from cycle 1 — still unaddressed, no blocker.)
- [ ] [2026-04-12 | "M76"] `lib/finalize_version.sh:42-44` — `_hook_project_version_tag` accepts `exit_code` as a parameter (with `# shellcheck disable=SC2034`) but never checks it — the hook guards on `_COMMIT_SUCCEEDED` instead. The unused parameter is harmless and the disable comment is appropriate, but the asymmetry with `_hook_project_version_bump` (which does check `exit_code`) is mildly confusing. Consider either checking `exit_code` here for defense-in-depth or adding a comment explaining why it is deliberately ignored.
- [ ] [2026-04-12 | "M75"] `lib/docs_agent.sh:76-79` / `stages/docs.sh:86-89` — The `sed` range expression extracting the Documentation Responsibilities section is duplicated verbatim in both files. Minor duplication; consider extracting to a shared helper when a third caller appears.
<!-- Items added here by the pipeline. Mark [x] when addressed. -->

## Resolved
