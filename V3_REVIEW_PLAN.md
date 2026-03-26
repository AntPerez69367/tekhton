# Tekhton V3 Final Review — Verification Plan

## Phase 1: Static Integrity (no execution, pure validation)

- [ ] **1. Run full test suite** — `bash tests/run_tests.sh` — all 251+ tests must pass
- [ ] **2. Shellcheck all source files** — `shellcheck tekhton.sh lib/*.sh stages/*.sh` — zero warnings
- [ ] **3. Bash syntax check** — `bash -n` on all .sh files
- [ ] **4. Python tool tests** — `cd tools && python3 -m pytest`
- [ ] **5. Version sanity** — Confirm TEKHTON_VERSION reflects 3.30.0 (all 30 milestones)
- [ ] **6. Manifest completeness** — All 30 milestones in MANIFEST.cfg marked done, all .md files present

## Phase 2: Clean-Room `--init` Test

- [ ] **7. Create clean snapshot branch** — safe rollback point
- [ ] **8. Strip pipeline footprint** — remove .claude/pipeline.conf, agents/, milestones/, settings.local.json, dashboard/, MILESTONE_ARCHIVE.md, DRIFT_LOG.md, ARCHITECTURE_LOG.md, HUMAN_NOTES.md, HUMAN_ACTION_REQUIRED.md, NON_BLOCKING_LOG.md, CLAUDE.md
- [ ] **9. Run `--init`** — verify scaffold creation with no crashes
- [ ] **10. Inspect generated scaffold** — compare against templates, no {{VAR}} literals

## Phase 3: `--plan` Test

- [ ] **11. Run `--plan` against clean scaffold** — full planning pipeline
- [ ] **12. Validate CLAUDE.md structure** — milestones, architecture, conventions
- [ ] **13. Verify DAG integrity** — MANIFEST.cfg created, milestone files exist

## Phase 4: Pipeline Execution Smoke Test

- [ ] **14. Run trivial task** — full scout→coder→build→reviewer→tester cycle
- [ ] **15. Verify runtime artifacts** — state files, logs, metrics, --status, --report
- [ ] **16. Verify resume** — interrupt and re-run, confirm resume from correct stage

## Phase 5: V3-Specific Feature Validation

- [ ] **17. Milestone DAG** — --milestone mode, --migrate-dag, --add-milestone
- [ ] **18. Repo map / indexer** — --setup-indexer, REPO_MAP.md generation
- [ ] **19. Causal log** — CAUSAL_LOG.jsonl exists, --diagnose works
- [ ] **20. Test baseline detection** — pre-existing failure handling
- [ ] **21. Express mode** — --init --full

## Phase 6: Brownfield Legacy Project Test

- [ ] **22. Pick legacy codebase** — messy structure, no Tekhton footprint
- [ ] **23. Run --init on legacy** — tech stack detection, reasonable defaults
- [ ] **24. Run --plan on legacy** — evaluate CLAUDE.md quality and accuracy
- [ ] **25. Run real task on legacy** — evaluate scout/coder/reviewer quality
- [ ] **26. Stress test --complete** — full autonomous loop observation

## Phase 7: Cleanup & Release Prep

- [ ] **27. Version bump** — TEKHTON_VERSION to 3.30.0, M30 marked done
- [ ] **28. Final test suite run** — green after all fixes
- [ ] **29. Clean up test branch** — merge findings or discard
- [ ] **30. Tag release** — `git tag -a v3.30.0`

## Decision Gates

| Gate | Pass Criteria |
|------|--------------|
| Phase 1 | 0 test failures, 0 shellcheck warnings, 0 syntax errors |
| Phase 2 | --init produces valid scaffold with no errors |
| Phase 3 | --plan produces quality CLAUDE.md |
| Phase 4 | Full pipeline completes end-to-end |
| Phase 5 | All V3 features function correctly |
| Phase 6 | Successfully onboards and runs against real legacy project |
| Phase 7 | Version bumped, tagged, all tests green |
