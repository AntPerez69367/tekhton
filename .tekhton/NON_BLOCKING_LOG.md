# Non-Blocking Notes Log

Accumulated reviewer notes that were not blocking but should be addressed.
Items are auto-collected from `## Non-Blocking Notes` in REVIEWER_REPORT.md.
The coder is prompted to address these when the count exceeds the threshold.

## Open
- [ ] [2026-04-19 | "M104"] `lib/init_helpers_display.sh` is present in the git diff but absent from the CODER_SUMMARY "Files Modified" list (carried from cycle 1 — documentation gap only; code is correct).
- [ ] [2026-04-19 | "M104"] `tests/test_output_lint.sh` and `tests/test_tui_no_dead_weight.sh` appear modified in git status but are not listed in CODER_SUMMARY. Both look correct; gap is documentation only.
- [x] [2026-04-19 | "M104"] Milestone doc `m104-tui-operation-liveness.md` §2 still refers to `run_op` living in `lib/tui.sh`; implementation correctly placed it in `lib/tui_ops.sh`. The milestone doc itself is now slightly stale (low-priority housekeeping).
- [ ] [2026-04-19 | "Implement Milestone 103: Output Bus Tests + Integration Validation"] `test_output_tui_sync.sh:126-129` (TC-TUI-03): `stage_order` assertion uses glob substring matching (`[[ "$json" == *'"intake"'* ]]`) instead of the JSON-parsed `assert_json_field` helper used in all other assertions. Works correctly, but inconsistent with the rest of the file and could produce a false pass if "intake" appeared in a different JSON field.
- [ ] [2026-04-19 | "Implement Milestone 103: Output Bus Tests + Integration Validation"] `tools/tests/test_tui_action_items.py:44`: `monkeypatch.setattr("tui_hold.time.sleep", ...)` patches by string reference, requiring `tui_hold` to already be in `sys.modules`. Works as long as `tui.py` imports `tui_hold` at module level, but the implicit dependency is fragile if that import path ever changes to lazy-loading.
- [ ] [2026-04-19 | "Implement Milestone 102: TUI-Aware Finalize + Completion Flow"] `lib/finalize.sh` is 571 lines — well above the 300-line ceiling. M102 adds only ~7 lines (the `_hook_tui_complete` function + registration call); the overage predates this milestone. Log for next cleanup pass.
- [ ] [2026-04-19 | "Implement Milestone 102: TUI-Aware Finalize + Completion Flow"] `lib/output_format.sh:227` — `$sev` is embedded unescaped into the JSON fragment in `_out_append_action_item`. Already flagged by the security agent (LOW/fixable); current callers only pass hardcoded literals so the risk is latent, but it should be routed through `_out_json_escape` before the first computed-severity caller lands.
- [ ] [2026-04-19 | "Implement Milestone 102: TUI-Aware Finalize + Completion Flow"] `lib/output_format.sh:237` — `_out_json_escape` does not strip JSON control characters U+0000–U+001F (excluding the explicitly handled ` `, ``, `	`). Already flagged LOW/fixable by the security agent. Add a `tr -d` pass or bash parameter expansion strip before the function returns.
- [ ] [2026-04-19 | "M101"] The `_out_color` implementation emits `printf ''` (no-op printf) in the NO_COLOR branch. Functionally correct (subshell capture returns ""), but `printf ''` is a more opaque idiom than a plain `return 0` or a `printf '%s' ""`. Not worth changing, but noting for future readability.

## Resolved
