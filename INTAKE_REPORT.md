## Verdict
PASS

## Confidence
88

## Reasoning
- Scope is well-defined: the Milestone Map display is not reflecting the ACTIVE state during execution, skipping from READY to DONE
- Expected vs actual behavior is unambiguous: milestones should appear in the Active column while running, not jump directly from READY to DONE
- Testability is clear: run a milestone and observe the Milestone Map during execution — the active milestone must appear in the Active column
- Similar Watchtower dashboard bugs (e.g., the Trends screen backslash bug) have passed intake and completed cleanly in a single cycle
- No migration impact: this is a display/state-tracking fix with no new config keys or file format changes
- Fix domain is well-scoped: milestone state transition logic in the dashboard data emission layer (dashboard_emitters.sh / milestones.sh / dashboard.sh area)
