## Test Audit Report

### Audit Summary
Tests audited: 2 files, 6 test cases
Verdict: CONCERNS

---

### Findings

#### INTEGRITY: Idempotency guard at plan_generate.sh:124–126 is never reached — tests pass regardless of guard correctness
- File: tests/test_plan_generate_marker_idempotency.sh:71 (Test 1), :200 (Test 3)
- Issue: Both tests pre-seed CLAUDE.md with `<!-- tekhton-managed -->` to exercise the guard that prevents duplicate marker insertion. The guard at `plan_generate.sh:124–126` is conditional on the file already containing the marker — but the guard only matters along two code paths: (a) `_disk_rescued=true` (captured output was non-heading, so on-disk file is reused without overwriting), or (b) captured output already contains the marker. The mock `_call_planning_batch` in both tests returns content beginning with `# Tekhton CLAUDE.md` (a heading), so `_captured_first == "#"*` → `_disk_rescued` stays `false`. The `if [[ "$_disk_rescued" == "false" ]]` branch at line 120 overwrites CLAUDE.md entirely before the guard runs, discarding the pre-seeded marker. The guard at line 124 then evaluates the freshly written content (no marker), appends once, and the tests pass. Removing the guard entirely and replacing it with an unconditional `echo "<!-- tekhton-managed -->" >> "$claude_md"` would not change the outcome of any of the 3 tests in this file. The guard is unprotected.
- Severity: HIGH
- Action: Redesign Tests 1 and 3 to reach the guard. Two scenarios require separate tests:
  1. `_disk_rescued=true` path — make `_call_planning_batch` return a non-heading summary string (e.g., `"I have generated the requested file."`) while CLAUDE.md already exists on disk with >20 substantive lines AND already contains `<!-- tekhton-managed -->`. The guard should prevent a second marker from being appended to the preserved on-disk content.
  2. Captured-output-already-has-marker — make `_call_planning_batch` return content that includes `<!-- tekhton-managed -->` inline. The guard should prevent a second marker after writing.

#### INTEGRITY: Test 3 "marker in middle" pre-condition is unreachable in the code path the mock triggers
- File: tests/test_plan_generate_marker_idempotency.sh:200
- Issue: Test 3 frames itself as an edge case where a "malformed" CLAUDE.md has the marker embedded mid-file. Because the mock always returns heading-first output, `_disk_rescued` is always `false`, and `plan_generate.sh:121` overwrites the file unconditionally before any deduplication logic can observe it. The pre-seeded "malformed" file is irrelevant — its content never enters the code path. The resulting assertions (marker count == 1, marker at end of file) are trivially true after a fresh write and provide no signal about deduplication behavior.
- Severity: HIGH
- Action: Remove Test 3 or replace it with a reachable scenario. A valid replacement: `_disk_rescued=true` with on-disk CLAUDE.md containing a mid-file marker (not at the last line). This would test whether the idempotency grep catches a marker that is not at EOF, verifying the guard does not fire even when the marker is mid-file.

#### NAMING: File and test case names promise "idempotency" but tests only exercise fresh-write appending
- File: tests/test_plan_generate_marker_idempotency.sh:1
- Issue: The file name, and the headings for Tests 1 and 3, use "idempotency" and "preexisting marker" — language that implies the deduplication guard is under test. In reality, all three tests exercise only the trivially-correct fresh-write path. A developer reviewing coverage would incorrectly believe the guard at `plan_generate.sh:124–126` is regression-protected. It is not.
- Severity: MEDIUM
- Action: Either (a) rename to `test_plan_generate_marker_appending.sh` and update test headings to reflect "marker appended on fresh write" (if Tests 1 and 3 are not redesigned), OR (b) keep the name and fix the tests as recommended under the INTEGRITY findings so the name accurately describes what is tested.

#### EXERCISE: `_trim_document_preamble` mock comment references wrong source file
- File: tests/test_init_synthesize_marker_appending.sh:55, :218, :320
- Issue: All three inner scripts have the comment `# Mock _trim_document_preamble (from lib/plan.sh)`. The function is actually defined in `lib/plan_batch.sh:125`, which `lib/plan.sh` sources at line 100. The mock is defined after `source lib/plan.sh` and before `source stages/init_synthesize.sh`, so the override is correctly ordered and the test behavior is unaffected — this is a stale comment only. However, it could mislead a maintainer searching for the real definition.
- Severity: LOW
- Action: Update all three instances to `# Mock _trim_document_preamble (from lib/plan_batch.sh)`.

---

### Per-File Integrity Summary

| File | Assertions Honest | Fixtures Isolated | Calls Real Code | Idempotency Guard Exercised | Verdict |
|------|-------------------|-------------------|-----------------|-----------------------------|---------|
| test_plan_generate_marker_idempotency.sh | Partially (values are correct for fresh-write, not for guard) | PASS (mktemp + trap) | PASS (sources stages/plan_generate.sh) | NO — mock prevents guard code path | CONCERNS |
| test_init_synthesize_marker_appending.sh | PASS | PASS (mktemp + trap) | PASS (sources stages/init_synthesize.sh) | n/a (_synthesize_claude has no guard by design) | PASS |

---

### Implementation Verification

**`stages/plan_generate.sh` — idempotency guard (lines 119–126):**
```
if [[ -n "$claude_md_content" ]]; then
    if [[ "$_disk_rescued" == "false" ]]; then
        printf '%s\n' "$claude_md_content" > "$claude_md"   # line 121 — unconditional overwrite
    fi
    if ! grep -q '<!-- tekhton-managed -->' "$claude_md" 2>/dev/null; then  # line 124
        echo "<!-- tekhton-managed -->" >> "$claude_md"
    fi
```
The guard at line 124 evaluates AFTER the possible overwrite at line 121. When `_disk_rescued=false` (the only path the tests exercise), line 121 always runs first, making the pre-seeded marker irrelevant. The guard only has meaningful work to do when `_disk_rescued=true` (overwrite skipped) and the on-disk file already carries the marker.

**`stages/init_synthesize.sh` — `_synthesize_claude()` (lines 174–178):**
```
printf '%s\n' "$claude_content" > "$claude_file"   # always overwrites
echo "<!-- tekhton-managed -->" >> "$claude_file"   # always appends, no guard
```
No idempotency guard present — correct by design, since `_synthesize_claude` always writes a fresh file. The tests in `test_init_synthesize_marker_appending.sh` correctly verify appending behavior without claiming to test a non-existent guard.
