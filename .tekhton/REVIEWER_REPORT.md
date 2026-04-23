# Reviewer Report — M122

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `lib/indexer_helpers.sh` header "Provides:" comment (lines 7–9) does not list `_indexer_emit_stderr_tail()`. The new function should appear there for consistency with every other helper module.
- `tests/test_indexer_typescript_smoke.sh:16` assigns `TMPDIR=$(mktemp -d)`, shadowing the standard env var of the same name. Downstream `mktemp` calls inside `run_repo_map` will inherit it (harmless — the value is a valid dir), but a non-reserved name (`TEST_TMPDIR` or `WORK_DIR`) would be clearer and avoids surprising OS tooling that inspects `TMPDIR`.
- `tests/test_indexer_typescript_smoke.sh:80` defines `_indexer_find_venv_python()` before the `source` calls, then redefines it at line 92 after sourcing. The pre-source stub is dead code — the function is not called during module load. Only the post-source redefinition at line 92 is needed; the earlier stub and its comment are misleading.

## Coverage Gaps
- M122's acceptance criteria calls for "a parametrized 'all grammars that import cleanly return a Language' test" to verify the new probe order doesn't regress non-TS extensions. No such parametrized test was added. The Non-Goals section defers the full-audit suite to M123, so this is expected — but the coverage gap should be on M123's radar.

## ACP Verdicts
(No Architecture Change Proposals in CODER_SUMMARY.md — section omitted.)

## Drift Observations
- None
