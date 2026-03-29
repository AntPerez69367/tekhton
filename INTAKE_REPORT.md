## Verdict
TWEAKED

## Confidence
55

## Reasoning
- Core intent is clear: auto-spawn a fix run when self-tests fail instead of exiting
- Missing acceptance criteria entirely — the milestone is a feature description, not a spec
- Implicit assumption: applies to `--human` mode (notes + task context), but not stated
- No infinite loop protection mentioned — spawned run could also fail tests, triggering another spawn
- No guidance on whether to prompt the user before spawning or proceed automatically
- No Watch For section or files-to-modify guidance
- No config opt-out mentioned for users who prefer the current "exit cleanly" behavior

## Tweaked Content

[FEAT] Currently if there are failures during the Tekhton Self-Tests, the pipeline gives its final summary and then notes there are failed tests and exits cleanly. Instead of exiting it should immediately spawn a fix run with the same notes + a new note to "Fix failed tests" so that the user can get right into fixing instead of having to trigger a new run manually.

[PM: Added scope clarification] **Scope:** This applies to `--human` mode runs where human notes are the task driver. When the pipeline exits with test failures, a new `--human` run is spawned automatically with the same note tag filter (if any) and a synthetic note prepended: `- [ ] Fix failed tests`. [PM: Confirm this scope — does this also apply to regular task runs? If so, what task string should the spawned run use?]

### Acceptance Criteria

[PM: No acceptance criteria in original — added below]

- When a `--human` run completes with one or more test failures, a follow-up `--human` run is automatically spawned (no manual re-invocation required)
- The spawned run includes all notes from the original run plus a new unchecked note: `- [ ] Fix failed tests`
- If the same test failures recur on the spawned run, the pipeline exits cleanly (no further auto-spawn — maximum one auto-spawn per original run to prevent infinite loops)
- If the original run had zero test failures, no auto-spawn occurs
- The auto-spawn behavior is guarded by a new config key `AUTO_SPAWN_ON_TEST_FAILURE` (default: `true`) so users can opt out
- The pipeline logs a clear banner before spawning: e.g., `[Tekhton] Test failures detected — spawning fix run...`
- `bash tests/run_tests.sh` passes after this change

### Watch For

[PM: No Watch For section in original — added below]

- **Infinite loop risk**: The spawned run must be marked so it does not trigger another auto-spawn on failure. Use a flag file (e.g., `.claude/state/auto_spawn_active`) or pass a `--no-auto-spawn` flag to the child invocation.
- **Note injection**: Prepend the new note to the top of the effective notes list so it appears first and is not lost among existing notes.
- **Exit code propagation**: If the spawned run fails, the outer process exit code should reflect that failure, not the original run's success.
- **Non-human mode**: If this feature is extended to task runs in the future, the spawned task string must be defined. Defer that case for now and document it as out of scope.

## Questions
- Should auto-spawn apply only to `--human` mode, or also to regular task runs? If regular task runs, what task string does the spawned run use?
- Should the user be prompted with a Y/N confirmation before the auto-spawn, or is it fully automatic?
