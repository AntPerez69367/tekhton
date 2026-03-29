# Reviewer Report

## Verdict
APPROVED

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- No code was changed this run — the fix was already present. HUMAN_NOTES.md item should be marked resolved so it doesn't resurface in future runs.

## Coverage Gaps
- None

## Drift Observations
- `lib/milestone_archival.sh:50-54` and `lib/milestone_archival.sh:63-65` repeat the identical DAG-mode guard (`MILESTONE_DAG_ENABLED == true` + `has_milestone_manifest`) twice within the same function. A local `is_dag_mode` variable set once at function entry would reduce duplication and make the condition easier to audit.
- The global-grep idempotency fix (passing `archive_initiative=""` in DAG mode) assumes milestone numbers are globally unique across all initiatives in a project's lifecycle. This holds for the current codebase but is not enforced structurally. If a project ever resets milestone numbering (e.g., a fresh DAG manifest starting at m01 after an earlier inline run), a prior milestone number in the archive could produce a false-positive match, silently skipping the new milestone. Worth a code comment explaining the uniqueness assumption.

---

## Review Notes

The fix at `lib/milestone_archival.sh:49-54` is correct and well-targeted. Root cause analysis matches the code: `_get_initiative_name()` returns the initiative containing the DAG pointer comment (the current one), not the initiative under which a given milestone was originally archived. Passing that name to `_milestone_in_archive()` scoped the search incorrectly, causing cross-initiative misses.

The fix — setting `archive_initiative=""` when DAG mode is active and a manifest is present — routes `_milestone_in_archive()` to the global grep path (`lib/milestone_archival_helpers.sh:117-119`), which correctly finds any milestone heading in the archive regardless of which initiative section it was written under.

`test_milestone_archival_dag_rearchive.sh` provides full regression coverage: 6 tests verify the original bug (cross-initiative milestones are not re-archived), 4 tests verify the positive case (new milestones still archive correctly and are idempotent on second call), and 1 test verifies no duplicate content is written. The test setup faithfully reproduces the real-world scenario (archive contains milestones from two older initiatives; DAG manifest contains m01/m02 mapped to numbers 1/2; CLAUDE.md has a V3 DAG pointer). Test suite passes 198/198 shell tests and 76/76 Python tests.
