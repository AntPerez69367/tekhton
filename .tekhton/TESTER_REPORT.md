## Planned Tests
- [x] `tools/tests/test_tree_sitter_languages.py` — Parametrized test: all grammars that import cleanly return a Language object (M122 acceptance criterion AC-3)
- [x] `tests/test_indexer_emit_stderr_tail.sh` — Unit tests for new `_indexer_emit_stderr_tail()` helper: empty file, content output, 5-line tail limit

## Test Run Results
Passed: 460  Failed: 0

Shell suite: 441 passed, 0 failed
Python suite: 202 passed, 14 skipped (grammar packages not installed), 0 failed

## Bugs Found
None

## Files Modified
- [x] `tools/tests/test_tree_sitter_languages.py`
- [x] `tests/test_indexer_emit_stderr_tail.sh`
