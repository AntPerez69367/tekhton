# Human Notes
<!-- notes-format: v2 -->
<!-- IDs are auto-managed by Tekhton. Do not remove note: comments. -->

Add your observations below as unchecked items. The pipeline will inject
unchecked items into the next coder run and archive them when done.

Use `- [ ]` for new notes. Use `- [x]` to mark items you want to defer/skip.

Prefix each note with a priority tag so the pipeline can scope runs correctly:
- `[BUG]` — something is broken, needs fixing before new features
- `[FEAT]` — new mechanic or system, architectural work
- `[POLISH]` — visual/UX improvement, no logic changes

## Features

## Bugs

- [x] [BUG] TUI Stage Timings panel has two related issues: (1) while a stage is active, elapsed time is shown in minutes+seconds (e.g. "1m 23s"), but once the stage completes it reverts to showing only seconds (e.g. "83s"); (2) the Review and Tester stages reset to 0s on completion regardless of actual elapsed time — their final recorded duration is always ~0s instead of the real value. They also show 0/0 turns regardless of how many they actually used.

## Polish
