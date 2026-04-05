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

## Polish
- [x] [POLISH] The Distribution section on the Trends page of Watchtower doesn't make it clear what it's calculating. Currently the Scout stage which takes the least amount of time shows as the most distribution which is confusing. If it's showing the distribution of time spent, it should be labeled as such. If it's showing the distribution of runs, it should also be labeled as such. We should also consider adding a tooltip or more detailed breakdown to clarify this further. Perhaps it needs two modes you can toggle between: distribution of time spent vs distribution of runs.
- [ ] [POLISH] The Watchtower text sizes are all fairly small, with some lines being nearly impossible to read like the "Milestone" column in the recent runs view. We should consider standard WCAG text sizes and spacing to improve readability.
