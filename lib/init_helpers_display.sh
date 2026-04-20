#!/usr/bin/env bash
set -euo pipefail
# =============================================================================
# init_helpers_display.sh — Detection-result rendering for smart init.
#
# Sourced by init_helpers.sh — do not run directly.
# Provides: _display_detection_results()
# =============================================================================

_display_detection_results() {
    local languages="$1"
    local frameworks="$2"
    local commands="$3"
    local entry_points="$4"
    local project_type="$5"

    echo >&2
    out_section "Detection Results" >&2
    out_kv "Project type" "${project_type}" >&2

    local _g _y _r _nc
    _g=$(_out_color "${GREEN:-}")
    _y=$(_out_color "${YELLOW:-}")
    _r=$(_out_color "${RED:-}")
    _nc=$(_out_color "${NC:-}")

    if [[ -n "$languages" ]]; then
        out_section "Languages" >&2
        while IFS='|' read -r lang conf manifest; do
            local icon="  "
            [[ "$conf" == "high" ]] && icon="${_g}✓${_nc}"
            [[ "$conf" == "medium" ]] && icon="${_y}~${_nc}"
            [[ "$conf" == "low" ]] && icon="${_r}?${_nc}"
            printf '%s\n' "    ${icon} ${lang} (${conf}) — ${manifest}" >&2
        done <<< "$languages"
    else
        out_kv "Languages" "none detected" warn >&2
    fi

    if [[ -n "$frameworks" ]]; then
        out_section "Frameworks" >&2
        while IFS='|' read -r fw lang _evidence; do
            printf '%s\n' "    ${_g}✓${_nc} ${fw} (${lang})" >&2
        done <<< "$frameworks"
    fi

    if [[ -n "$commands" ]]; then
        out_section "Commands" >&2
        while IFS='|' read -r cmd_type cmd _source conf; do
            local icon="${_g}✓${_nc}"
            [[ "$conf" == "medium" ]] && icon="${_y}~${_nc}"
            [[ "$conf" == "low" ]] && icon="${_r}?${_nc}"
            printf '%s\n' "    ${icon} ${cmd_type}: ${cmd}" >&2
        done <<< "$commands"
    fi

    if [[ -n "$entry_points" ]]; then
        out_section "Entry points" >&2
        while IFS= read -r ep; do
            printf '%s\n' "    ${ep}" >&2
        done <<< "$entry_points"
    fi
    echo >&2
}
