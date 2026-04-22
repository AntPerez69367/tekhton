#!/usr/bin/env bash
# =============================================================================
# tui_ops_substage.sh — Hierarchical substage API (M113).
#
# Sourced by lib/tui.sh after lib/tui_ops.sh — do not run directly.
#
# A substage is a transient phase (scout inside coder, rework inside review,
# architect-remediation inside architect) that runs *inside* an already-open
# pipeline stage. The substage API records which substage is currently active
# without mutating the parent stage's live row, start timestamp, lifecycle id,
# or the _TUI_STAGES_COMPLETE record array. This lets renderers (M114)
# attribute events to the substage while the stage-timings panel continues to
# reflect the coherent pipeline timeline.
#
# All functions are no-ops when _TUI_ACTIVE != true or TUI_LIFECYCLE_V2=false.
# No caller is migrated in M113; the API is dormant until M114.
# =============================================================================
set -euo pipefail
# shellcheck source=lib/tui.sh

# tui_substage_begin LABEL [MODEL]
# Declare a substage active inside the currently open pipeline stage. Records
# _TUI_CURRENT_SUBSTAGE_LABEL and _TUI_CURRENT_SUBSTAGE_START_TS and flushes
# the status file. Parent stage state (label, start ts, lifecycle id) and the
# _TUI_STAGES_COMPLETE array are intentionally untouched — substages are
# breadcrumbs, not timeline entries.
tui_substage_begin() {
    [[ "${_TUI_ACTIVE:-false}" == "true" ]] || return 0
    [[ "${TUI_LIFECYCLE_V2:-true}" == "true" ]] || return 0
    local label="${1:-}"
    [[ -z "$label" ]] && return 0
    _TUI_CURRENT_SUBSTAGE_LABEL="$label"
    _TUI_CURRENT_SUBSTAGE_START_TS=$(date +%s)
    _tui_write_status
}

# tui_substage_end LABEL [VERDICT]
# Clear the active substage and flush the status file. LABEL and VERDICT are
# accepted for call-site symmetry with tui_stage_end but are not retained —
# substage completion is not appended to _TUI_STAGES_COMPLETE.
tui_substage_end() {
    [[ "${_TUI_ACTIVE:-false}" == "true" ]] || return 0
    [[ "${TUI_LIFECYCLE_V2:-true}" == "true" ]] || return 0
    _TUI_CURRENT_SUBSTAGE_LABEL=""
    _TUI_CURRENT_SUBSTAGE_START_TS=0
    _tui_write_status
}

# _tui_autoclose_substage_if_open — called from tui_stage_end.
# If the parent stage closes while a substage is still active (crash, early
# return, forgotten end call), emit a single warn event into the Recent
# events ring buffer and clear the substage globals. Gated on the same V2
# flag as the public API so opt-out users never see the warning.
_tui_autoclose_substage_if_open() {
    [[ "${_TUI_ACTIVE:-false}" == "true" ]] || return 0
    [[ "${TUI_LIFECYCLE_V2:-true}" == "true" ]] || return 0
    local sublabel="${_TUI_CURRENT_SUBSTAGE_LABEL:-}"
    [[ -z "$sublabel" ]] && return 0
    _TUI_CURRENT_SUBSTAGE_LABEL=""
    _TUI_CURRENT_SUBSTAGE_START_TS=0
    tui_append_event "warn" "[tui] substage '${sublabel}' auto-closed by parent end"
}
