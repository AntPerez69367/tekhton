# Human Notes

Add your observations below as unchecked items. The pipeline will inject
unchecked items into the next coder run and archive them when done.

Use `- [ ]` for new notes. Use `- [x]` to mark items you want to defer/skip.

Prefix each note with a priority tag so the pipeline can scope runs correctly:
- `[BUG]` — something is broken, needs fixing before new features
- `[FEAT]` — new mechanic or system, architectural work
- `[POLISH]` — visual/UX improvement, no logic changes


## Features
- [x] [FEAT] The NON_BLOCKING_LOG.md has an excellent mechanic of using `[ ]` and `[X]` to denote to-do and completed items, but it never gets tidied up. Currently after items have been picked up from the log and completed they are marked as `[X]`. Let's extend that slightly so that on a new run before we pick up the `[ ]` items we first clear any leftover `[X]` items so that we only ever see the last ones tackled. Also, from now on the items we complete from both the NON_BLOCKING_LOG and the DRIFT_LOG should be included in the final commit message. Then we can stop archiving them forever.

## Bugs
None currently.

## Polish
None currently.