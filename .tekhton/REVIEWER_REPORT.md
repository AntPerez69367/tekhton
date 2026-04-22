# Reviewer Report — M114: TUI Renderer + Scout Substage Migration

## Verdict
APPROVED_WITH_NOTES

## Complex Blockers (senior coder)
- None

## Simple Blockers (jr coder)
- None

## Non-Blocking Notes
- `test_substage_blanks_turns_column` only asserts `--/50` is absent; it does not directly assert the turns cell is empty. The inverse guard is functionally sufficient but doesn't prove the positive (blank cell). Low-risk, worth strengthening in a future test pass.
- `test_parent_timer_continues_across_substage_boundary` uses `.split("(", 1)[0]` to exclude trailing panel text when checking that `5s` is absent. The comment acknowledges this is "crude but sufficient". The assertion is correct for current panel layout but could become a false negative if rich adds a `(` in the label before the timer column. Log for future hardening.
- The `declare -f tui_substage_begin` guard in `stages/coder.sh` is correct and consistent with how other lib functions are guarded in `lib/common.sh`, `lib/output.sh`, etc. It is slightly redundant because `tui_substage_begin` already gates on `_TUI_ACTIVE == true`, but the double-guard is harmless and follows established convention.
- `tui_substage_begin` accepts a second MODEL argument (as called from `stages/coder.sh:237`), but `lib/tui_ops_substage.sh` never binds or uses `$2`. The argument is silently dropped. Not a bug — the value cannot cause harm and the call-site comment explains intent — but future readers may wonder why the model is passed. A `local _model="${2:-}"` in the function body or removal of the arg from the call site would remove the ambiguity.

## Coverage Gaps
- No test exercises the `tui_substage_end` call path in `stages/coder.sh` at the integration level (i.e., verifying that the `current_substage_label` clears from `tui_status.json` after scout exits). The unit test `test_missing_substage_keys_tolerated` covers the renderer's no-substage path but not the end-to-end clearing flow. The M113 contract test in `tests/test_tui_substage_api.sh` partially covers this at the bash level.

## Drift Observations
- `lib/tui_ops_substage.sh:27-35` — `tui_substage_begin` signature accepts a MODEL positional arg (documented in the function header comment as `tui_substage_begin LABEL [MODEL]`) but the body only assigns `label="${1:-}"`. The MODEL is never stored or forwarded anywhere. If future milestones want to display the substage model in the TUI, the infrastructure to pass it in is already present at the call site (`${CLAUDE_SCOUT_MODEL:-}`) but the receiving code is absent. Either document the ignore explicitly with a `local _model="${2:-}"` binding, or remove MODEL from the public signature in the header comment to avoid confusion.
