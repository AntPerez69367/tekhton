# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-05 | "M58"] `platforms/web/detect.sh` has no `set -euo pipefail` header. Project convention applies to all `.sh` files. Since this file is always sourced (never executed directly), it inherits the caller's flags and is functionally correct, but the omission deviates from the project standard. Add as the first executable line after the comment block.
- [ ] [2026-04-05 | "M58"] `tests/test_platform_web.sh` is 381 lines, over the 300-line ceiling. The test structure is clean and all 29 tests are well-scoped — the length comes from fixture setup verbosity. Candidate for split into `test_platform_web_detection.sh` and `test_platform_web_fragments.sh` in a future cleanup pass.
(none)

## Resolved
