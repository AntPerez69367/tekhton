## Verdict
TWEAKED

## Confidence
52

## Reasoning
- Core intent is clear: promote Live Run from an isolated page to a persistent, always-visible banner
- Zero acceptance criteria — no specification of what the banner displays, when it appears/hides, or what "every page" means concretely
- The old Live Run page disposition is unspecified (remove? redirect? keep as expanded view?)
- No UI testability criteria despite being a pure UI change
- Related human note about auto-refresh scope suggests the banner should also be exempt from unnecessary refreshes (already flagged separately, but worth noting)
- Filling these gaps with reasonable defaults yields a workable milestone

## Tweaked Content

### [BUG] Watchtower: Promote Live Run to a persistent top-of-page banner

**Problem:** The Live Run page occupies its own route and requires navigation to see run progress. When a pipeline is active, users lose visibility the moment they navigate away.

**Goal:** Replace the standalone Live Run page with a persistent banner rendered at the top of every Watchtower page, showing live run status whenever a run is active and hiding when no run is in progress.

**Scope:**
- Add a persistent Live Run banner component to the shared layout (renders on all pages)
- Banner is **only visible when a run is active**; hidden (zero height, no layout shift) otherwise
- [PM: existing Live Run route should be removed or redirected to the Reports page to avoid a dead link — if a dedicated expanded view is needed in the future that is a separate task]
- [PM: banner content should match what the current Live Run page shows — at minimum: current stage name, overall progress indicator, elapsed time, and a status label (running / succeeded / failed). If the existing page shows more, carry it all over.]
- Auto-refresh for live data applies to the banner on all pages [PM: coordinate with the separate auto-refresh scope bug — banner polling should be independent of page-level refresh]

**Acceptance Criteria:**
- [PM: added] Banner appears at the top of every Watchtower page (Reports, Trends, Actions, and any others) when a run is active
- [PM: added] Banner is not rendered (no empty space) when no run is active
- [PM: added] Banner displays at minimum: active stage, progress, elapsed time, and run status
- [PM: added] Navigating between pages does not reset or flicker the banner
- [PM: added] The former Live Run page route returns a redirect or 404 (not a broken blank page)
- [PM: added] Banner renders without console errors on all pages at desktop and mobile breakpoints
- [PM: added] If a run completes while the user is on any page, the banner transitions to a final state (succeeded/failed) and then hides after a short delay (e.g. 5 seconds) — or hides immediately on next navigation

## Questions
- Should the banner be collapsible/dismissible by the user, or always fully visible when a run is active?
- Is there a dedicated "expanded Live Run view" use case that should be preserved (e.g., clicking the banner expands details), or is full removal of the page correct?
