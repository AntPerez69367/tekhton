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
- [x] [BUG] On the Watchtower dasboard the Trends screen has a "recent runs" section that for each run generates more than one line, many of which are blank and marked as "HUMAN FEAT". These appear to be getting generated with 0 turns and 0s between each run. Sometimes 1, somtimes upwards of 9 of them. This is likely a bug in the code that generates the trends data for the dashboard, causing it to create multiple entries per run instead of just one.
