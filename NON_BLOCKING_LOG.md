# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-05 | "[POLISH] The Distribution section on the Trends page of Watchtower doesn't make it clear what it's calculating. Currently the Scout stage (which takes the least time) shows as the highest distribution, which is confusing to users who expect distribution to reflect time spent."] `templates/watchtower/app.js:783` — The "Run Count" toggle button label is a misnomer. The mode computes `avgT = stageTotals[sn].turns / cnt` (average turns per stage) and the tooltip confirms this with "N turns avg". It is not a count of how many runs included that stage (`stageTurnCount[sn]` fills that role). "Avg Turns" or "Turn Budget" would be more accurate and avoids re-introducing the same conceptual confusion the task was meant to fix.
- [ ] [2026-04-05 | "[POLISH] The Distribution section on the Trends page of Watchtower doesn't make it clear what it's calculating. Currently the Scout stage (which takes the least time) shows as the highest distribution, which is confusing to users who expect distribution to reflect time spent."] `templates/watchtower/style.css:302` — The `.dist-btn` elements have no `aria-pressed` attribute. The visual active state is present via `.active`, but screen readers cannot infer which toggle is selected. Adding `aria-pressed="true/false"` (set during event listener handling) would satisfy WCAG 4.1.2.
- [ ] [2026-04-05 | "M57"] `tests/test_platform_base.sh` is 342 lines, 42 over the 300-line soft ceiling. Code works; defer to cleanup pass.
- [ ] [2026-04-05 | "M57"] `detox` is mapped to `mobile_flutter` in `platforms/_base.sh` — Detox is a React Native testing framework, not Flutter. Once M60 populates `mobile_flutter/` with platform-specific content, React Native projects will receive incorrect Flutter guidance. Consider removing this mapping or revisiting when M60 scopes React Native support.

## Resolved
