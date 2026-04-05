# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-05 | "M57"] `tests/test_platform_base.sh` is 342 lines, 42 over the 300-line soft ceiling. Code works; defer to cleanup pass.
- [ ] [2026-04-05 | "M57"] `detox` is mapped to `mobile_flutter` in `platforms/_base.sh` — Detox is a React Native testing framework, not Flutter. Once M60 populates `mobile_flutter/` with platform-specific content, React Native projects will receive incorrect Flutter guidance. Consider removing this mapping or revisiting when M60 scopes React Native support.
(none)

## Resolved
