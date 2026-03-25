# Reviewer Report — Milestone 26: Express Mode (Re-review, Cycle 2)

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `lib/express.sh` is 331 lines — 31 over the 300-line soft ceiling. If this module grows (e.g. more manifest formats, persist strategies), consider splitting persist/role sub-concerns into a `lib/express_persist.sh`.
- `persist_express_config()` has no cleanup trap on its tmpfile. If the process is killed between `mktemp` and `mv`, a stale `.claude/express_conf_XXXXXX` is left in `.claude/`. Same LOW-severity pattern as the security-agent finding in `init_config.sh` — add `trap 'rm -f "$tmpfile"' EXIT INT TERM` immediately after the `mktemp` call.
- `_hook_express_persist` always logs "Express config saved to .claude/pipeline.conf. Edit to customize." even when `persist_express_config()` no-ops (conf already exists on run 2+). The inner function also logs its own success message on actual write, so run 1 produces two "saved" lines. Add a guard or move the outer log inside the function.
- `_detect_express_project_name()` uses `grep -oP` (PCRE), which is not available on macOS/BSD grep. Acceptable for the current Linux/WSL2 target, but worth noting if portability goals expand.
- Test 6.2 comment reads "resolve_role_file emits a log() line to stdout before the path" — this is incorrect. The `log` call inside `resolve_role_file()` is explicitly redirected to stderr (`>&2`). The `| tail -1` in the test is therefore unnecessary (though harmless). Update the comment to match reality.

## Coverage Gaps
- `enter_express_mode()` is not integration-tested end-to-end. The CLAUDE.md stub creation and `.claude/logs` mkdir are untested paths.
- `_hook_express_persist` (finalize hook) has no unit test. Specifically: the "no-op when conf already exists" and "persists roles when EXPRESS_PERSIST_ROLES=true" branches are unexercised.

## ACP Verdicts
- ACP: Role file fallbacks live in `express.sh`, not `agent.sh` — **ACCEPT** — Keeps `agent.sh` clean; role-fallback logic is conceptually part of the zero-config story and the placement is well-justified.
- ACP: `apply_role_file_fallbacks()` runs for configured projects too — **ACCEPT** — Strictly additive; the log message makes the fallback visible when it fires. The change in failure mode (hard error → logged fallback) is a resilience improvement and backward-compatible.

## Drift Observations
- `lib/express.sh:219-226` and `lib/express.sh:87-95` — `_csrc`, `_cconf` (enter_express_mode loop) and `_source`, `_conf` (generate_express_config loop) are assigned by `read -r` inside functions but not declared `local`, making them implicit globals after the loop. This matches the broader codebase pattern for IFS-split discard variables but creates quiet namespace pollution. Low risk given the `_` prefix convention.
- `lib/finalize.sh` — `_hook_express_persist` is registered between `_hook_emit_run_summary` and `_hook_commit`. On the first successful express run the committed snapshot will not include `pipeline.conf` (config is written after archive but before the commit hook fires — but the commit message does not stage the new file). Users will need to manually `git add .claude/pipeline.conf` or the file lands in the next commit. Consider whether this ordering is intentional.
