# Coder Summary

## Status: COMPLETE

## What Was Implemented

M122 — Indexer Multi-Grammar Package Support + Diagnostic Plumbing
(TypeScript Fix). Closes Issue #181.

- **Goal 1 — Factory-function probe.** `tools/tree_sitter_languages.py`
  `get_language()` now probes `language_<lang_name>` first (e.g.
  `language_typescript`, `language_tsx` on `tree_sitter_typescript`)
  before falling back to the single-grammar `language` / `LANGUAGE`
  conventions. Uses the `lang_name` already unpacked from
  `_EXT_TO_LANG`. Cache key
  (`f"{module_name}.{lang_name}"`) already disambiguates `.ts` vs
  `.tsx` so the two return distinct cached `Language` objects.
- **Goal 2 — Stderr diagnostic plumbing.** `lib/indexer.sh`
  `run_repo_map()`: moved `rm -f "$stderr_output"` out of the stats-
  parse block; on fatal exit (exit 2 or empty content) the new warning
  now includes a `[indexer] Last lines of repo_map.py stderr:` block
  with the tail of the Python tool's stderr. The emitter lives in
  `lib/indexer_helpers.sh` as `_indexer_emit_stderr_tail()` to keep
  `indexer.sh` under the 300-line ceiling. Cleanup happens exactly
  once before return on every branch.
- **Goal 3 — Unit tests.** Added four TS/TSX loader tests in
  `tools/tests/test_tree_sitter_languages.py::TestTypescriptGrammarLoading`,
  all gated on `pytest.importorskip("tree_sitter_typescript")`. Each
  test clears `_lang_cache` in `setup_method` so the loader is exercised
  fresh, not hitting stale state from other tests.
- **Goal 4 — Fixture coverage.** Added
  `tests/fixtures/indexer_project/web/client.ts` (exported function +
  interface) and `tests/fixtures/indexer_project/web/component.tsx`
  (typed React component). Integration tests
  `test_extract_tags_typescript_file` and `test_extract_tags_tsx_file`
  assert `_extract_tags()` returns definitions for `fetchUser` and
  `Greeting` respectively; both skip-on-missing-grammar.
- **Goal 5 — End-to-end smoke test.** New
  `tests/test_indexer_typescript_smoke.sh` verifies:
    - Positive: TS-only project with three `.ts` files produces a
      non-empty repo map containing `## src/` headings; `run_repo_map`
      exits 0.
    - Negative: repo_map.py is swapped for a stub that exits 2 with
      "Warning: no files could be parsed" — `run_repo_map` returns
      non-zero, the warning includes the `[indexer] Last lines of
      repo_map.py stderr:` header, and the stderr tail shows the
      actionable Python-side error.
  The whole test skips cleanly (exit 0 + SKIP line) when the indexer
  venv or `tree_sitter_typescript` is unavailable.
- **Goal 6 — Auto-discovery.** `tests/run_tests.sh` globs
  `test_*.sh` files, so no explicit registration is required.

## Root Cause (bugs only)

Two independent defects combined to silently hollow out the indexer on
TS-heavy projects:

1. `get_language()` only probed `mod.language` / `mod.LANGUAGE`.
   `tree_sitter_typescript` ships no such symbol — only
   `language_typescript()` and `language_tsx()`. Every `.ts`/`.tsx`
   file therefore returned `None` from `get_parser`, `_extract_tags`
   returned `None`, `all_tags` stayed empty, and `repo_map.py` exited
   2 with "no files could be parsed".
2. `run_repo_map` captured Python stderr to a tempfile, parsed stats
   out of it, and then `rm -f`-ed the file *before* the fatal-exit
   warning fired. Users saw only the generic fallback line with no
   actionable diagnostic.

## Files Modified

- `tools/tree_sitter_languages.py` — multi-grammar factory probe in
  `get_language()`.
- `lib/indexer.sh` — stderr preservation + call to
  `_indexer_emit_stderr_tail` on fatal exit; single end-of-function
  cleanup.
- `lib/indexer_helpers.sh` — new `_indexer_emit_stderr_tail()` helper
  (extracted from `indexer.sh` to stay under 300 lines).
- `tools/tests/test_tree_sitter_languages.py` — new
  `TestTypescriptGrammarLoading` class (4 tests).
- `tools/tests/test_extract_tags_integration.py` — new
  `TestExtractTagsTypescript` class (2 tests).
- `tests/fixtures/indexer_project/web/client.ts` (NEW) — TS fixture.
- `tests/fixtures/indexer_project/web/component.tsx` (NEW) — TSX
  fixture.
- `tests/test_indexer_typescript_smoke.sh` (NEW) — end-to-end smoke
  test, positive + negative paths.

## Human Notes Status

The task body listed no items under a Human Notes section, only the
Clarifications block (which concerned unrelated earlier runs about
Watchtower, NON_BLOCKING_LOG, `--init` flow, and HUMAN_NOTES
consistency — none relevant to M122). The CLARIFICATIONS.md file is
left untouched. No notes to mark.

## Docs Updated

None — no public-surface changes in this task. The change is purely
internal: a probe order inside `get_language()` and a diagnostic
surfacing change in `run_repo_map`. No new CLI flags, no new config
keys, no changed function signatures. The `CLAUDE.md` entry for
`lib/indexer_helpers.sh` already describes it broadly as "Language
detection, config validation, file extraction" — the new
`_indexer_emit_stderr_tail` helper is an internal symbol and does not
need doc mention.

## Observed Issues (out of scope)

- `tests/test_tui_lifecycle_invariants.sh` failed once during the full
  suite run but passes reliably in isolation (ran it 3 times
  standalone, all pass; ran `run_tests.sh` a second time and it passed
  there too). The error was
  `/tmp/tmp.XXX/status.json.tmp: No such file or directory` from
  `lib/tui.sh:272`, suggesting a race between parallel test tmpdir
  cleanup and the TUI sidecar's atomic-write pattern. Pre-existing
  flakiness, not caused by M122 — none of M122's edits touch TUI
  lifecycle code.
