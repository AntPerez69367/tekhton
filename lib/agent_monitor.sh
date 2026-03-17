#!/usr/bin/env bash
# agent_monitor.sh — Agent monitoring, activity detection, process management
# Sourced by agent.sh. Provides: _invoke_and_monitor(), _detect_file_changes(),
# _count_changed_files_since(), _kill_agent_windows()

# File scan depth for change detection (configurable via pipeline.conf)
: "${AGENT_FILE_SCAN_DEPTH:=8}"

# GNU coreutils timeout supports --kill-after; macOS/BSD does not. Detect once.
_TIMEOUT_KILL_AFTER_FLAG=""
if command -v timeout &>/dev/null && timeout --help 2>&1 | grep -q 'kill-after'; then
    _TIMEOUT_KILL_AFTER_FLAG="--kill-after=60"
fi

# Windows-native claude.exe doesn't receive POSIX signals from MSYS2/WSL interop.
# When detected, the abort handler uses taskkill.exe to terminate the process.
_AGENT_WINDOWS_CLAUDE=false
_claude_path="$(command -v claude 2>/dev/null || true)"

if grep -qiE 'microsoft|WSL' /proc/version 2>/dev/null; then
    if echo "${_claude_path:-}" | grep -qiE '(/mnt/c/|\.exe$|AppData|Program)'; then
        _AGENT_WINDOWS_CLAUDE=true
        warn "[agent] WARNING: claude appears to be a Windows binary running via WSL interop."
        warn "[agent] To fix: install claude natively in WSL (npm install -g @anthropic-ai/claude-code)."
    fi
elif uname -s 2>/dev/null | grep -qiE 'MINGW|MSYS'; then
    if [ -n "${_claude_path:-}" ]; then
        _AGENT_WINDOWS_CLAUDE=true
    fi
fi

# taskkill.exe reliably terminates Windows-native processes ignoring POSIX signals.
_kill_agent_windows() {
    if [ "$_AGENT_WINDOWS_CLAUDE" != true ]; then
        return
    fi
    local _tk=""
    if command -v taskkill.exe &>/dev/null; then
        _tk="taskkill.exe"
    elif command -v taskkill &>/dev/null; then
        _tk="taskkill"
    else
        return
    fi

    # Try PID-based kill first (more precise, avoids killing unrelated claude instances)
    if [ -n "${_TEKHTON_AGENT_PID:-}" ]; then
        $_tk //F //PID "$_TEKHTON_AGENT_PID" //T 2>/dev/null || true
    fi
    # Fall back to image-name kill to catch child processes the PID kill might miss
    # //F = force, //T = kill process tree, //IM = by image name.
    $_tk //F //IM claude.exe //T 2>/dev/null || true
}

# FIFO-monitored claude invocation. Sets _MONITOR_EXIT_CODE. Caller sets _IM_PERM_FLAGS.
_invoke_and_monitor() {
    local _invoke="$1"
    local model="$2"
    local max_turns="$3"
    local prompt="$4"
    local log_file="$5"
    local _activity_timeout="$6"
    local _session_dir="$7"
    local _exit_file="$8"
    local _turns_file="$9"

    _MONITOR_EXIT_CODE=1
    _MONITOR_WAS_ACTIVITY_TIMEOUT=false

    # FIFO: claude in bg subshell → pipe → foreground reader (ctrl+c, activity timeout)
    if command -v mkfifo &>/dev/null; then
        local _fifo="${_session_dir}/agent_fifo_$$"
        rm -f "$_fifo"
        mkfifo "$_fifo"

        # Background: run claude, write to FIFO (stdin=/dev/null)
        (
            $_invoke claude \
                --model "$model" \
                "${_IM_PERM_FLAGS[@]}" \
                --max-turns "$max_turns" \
                --output-format json \
                -p "$prompt" \
                < /dev/null \
                > "$_fifo" 2>&1
            echo "$?" > "$_exit_file"
        ) &
        _TEKHTON_AGENT_PID=$!

        # Trap: kill bg + Windows claude; reader gets EOF when fd closes
        _run_agent_abort() {
            trap - INT TERM
            _TEKHTON_CLEAN_EXIT=true
            if [ -n "${_TEKHTON_AGENT_PID:-}" ]; then
                kill "$_TEKHTON_AGENT_PID" 2>/dev/null || true
                kill -9 "$_TEKHTON_AGENT_PID" 2>/dev/null || true
            fi
            _kill_agent_windows
            rm -f "${_fifo:-}" 2>/dev/null || true
        }
        trap '_run_agent_abort' INT TERM

        # Foreground: read FIFO, log, parse JSON, detect silence + file changes
        (
            exec 3>>"$log_file"
            _last_activity=$(date +%s)
            _last_line=""
            _read_interval="${AGENT_ACTIVITY_POLL:-30}"
            [ "$_activity_timeout" -le 0 ] 2>/dev/null && _read_interval=0

            _activity_marker="${_session_dir}/activity_marker"
            touch "$_activity_marker"

            while true; do
                if [ "$_read_interval" -gt 0 ]; then
                    if IFS= read -r -t "$_read_interval" line; then
                        _last_activity=$(date +%s)
                        echo "$line" >&3
                        _last_line="$line"
                        if echo "$line" | grep -q '"type":"text"'; then
                            echo "$line" | python3 -c \
                                "import sys,json; d=json.load(sys.stdin); print(d.get('text',''))" \
                                2>/dev/null || true
                        fi
                    else
                        _rc=$?
                        if [ "$_rc" -le 128 ]; then
                            break  # EOF — claude exited
                        fi
                        # read timed out — check for silence
                        _now=$(date +%s)
                        _idle=$(( _now - _last_activity ))
                        if [ "$_idle" -ge "$_activity_timeout" ]; then
                            # Before killing: check if files changed since last marker.
                            # JSON output mode produces no FIFO output, but the agent
                            # may be actively writing files. If so, reset the timer.
                            _files_changed=false
                            if [ -f "$_activity_marker" ]; then
                                _changed_file=$(find "${PROJECT_DIR:-.}" -maxdepth "$AGENT_FILE_SCAN_DEPTH" \
                                    -newer "$_activity_marker" \
                                    -not -path '*/.git/*' \
                                    -not -path '*/.git' \
                                    -not -path "${_session_dir}/*" \
                                    -not -path "${LOG_DIR:-${PROJECT_DIR:-.}/.claude/logs}/*" \
                                    -type f 2>/dev/null | head -1)
                                if [ -n "$_changed_file" ]; then
                                    _files_changed=true
                                fi
                            fi

                            if [ "$_files_changed" = true ]; then
                                # Files changed — agent is actively working despite
                                # no FIFO output. Reset the activity timer.
                                echo "[tekhton] Activity timeout reached but files changed — resetting timer." >&3
                                _last_activity=$(date +%s)
                                touch "$_activity_marker"
                            else
                                echo "[tekhton] ACTIVITY TIMEOUT — no output or file changes for ${_idle}s. Killing agent." >&3
                                echo "ACTIVITY_TIMEOUT" > "$_exit_file"
                                kill "$_TEKHTON_AGENT_PID" 2>/dev/null || true
                                sleep 2
                                kill -9 "$_TEKHTON_AGENT_PID" 2>/dev/null || true
                                _kill_agent_windows
                                break
                            fi
                        fi
                    fi
                else
                    # Activity timeout disabled — blocking read
                    if IFS= read -r line; then
                        echo "$line" >&3
                        _last_line="$line"
                        if echo "$line" | grep -q '"type":"text"'; then
                            echo "$line" | python3 -c \
                                "import sys,json; d=json.load(sys.stdin); print(d.get('text',''))" \
                                2>/dev/null || true
                        fi
                    else
                        break  # EOF
                    fi
                fi
            done

            # Extract turn count from final result object
            _turns=$(echo "$_last_line" | python3 -c \
                "import sys,json; d=json.load(sys.stdin); print(d.get('num_turns', 0))" \
                2>/dev/null || echo "0")
            echo "$_turns" > "$_turns_file"
            exec 3>&-
        ) < "$_fifo"

        # Wait for background subshell to fully exit
        wait "$_TEKHTON_AGENT_PID" 2>/dev/null || true
        rm -f "$_fifo"

        # Read exit code from background subshell
        if [ -f "$_exit_file" ]; then
            _MONITOR_EXIT_CODE=$(cat "$_exit_file")
            if [ "$_MONITOR_EXIT_CODE" = "ACTIVITY_TIMEOUT" ]; then
                _MONITOR_EXIT_CODE=124
                _MONITOR_WAS_ACTIVITY_TIMEOUT=true
            fi
            [[ "$_MONITOR_EXIT_CODE" =~ ^[0-9]+$ ]] || _MONITOR_EXIT_CODE=1
            rm -f "$_exit_file"
        else
            _MONITOR_EXIT_CODE=1
        fi
    else
        # =================================================================
        # FALLBACK: direct pipeline (mkfifo not available — extremely rare)
        # =================================================================
        # WARNING: Ctrl+C may not work if claude hangs, and there is no
        # activity timeout. This path exists only for exotic environments
        # without mkfifo (no known modern system lacks it).
        _run_agent_abort() {
            trap - INT TERM
            _TEKHTON_CLEAN_EXIT=true
            kill 0 2>/dev/null || true
        }
        trap '_run_agent_abort' INT TERM

        $_invoke claude \
            --model "$model" \
            "${_IM_PERM_FLAGS[@]}" \
            --max-turns "$max_turns" \
            --output-format json \
            -p "$prompt" \
            < /dev/null \
            2>&1 | tee -a "$log_file" | (
                local turns=0
                local last_line=""
                while IFS= read -r line; do
                    if echo "$line" | grep -q '"type":"text"'; then
                        echo "$line" | python3 -c \
                            "import sys,json; d=json.load(sys.stdin); print(d.get('text',''))" \
                            2>/dev/null || true
                    fi
                    last_line="$line"
                done
                turns=$(echo "$last_line" | python3 -c \
                    "import sys,json; d=json.load(sys.stdin); print(d.get('num_turns', 0))" \
                    2>/dev/null || echo "0")
                echo "$turns" > "$_turns_file"
            )
        _MONITOR_EXIT_CODE=${PIPESTATUS[0]}
    fi
}

# --- File-change detection helpers (FIFO loop + null-run detection) -----------

# _detect_file_changes — 0 if files changed since marker, 1 otherwise.
_detect_file_changes() {
    local marker="$1"
    local project_dir="${PROJECT_DIR:-.}"
    local log_dir="${LOG_DIR:-${project_dir}/.claude/logs}"

    # Exclude .git, session temp, and log dir. Limit to 1 match.
    local changed
    changed=$(find "$project_dir" -maxdepth "$AGENT_FILE_SCAN_DEPTH" -newer "$marker" \
        -not -path '*/.git/*' \
        -not -path '*/.git' \
        -not -path "${TEKHTON_SESSION_DIR:-/nonexistent}/*" \
        -not -path "${log_dir}/*" \
        -type f 2>/dev/null | head -1)

    if [ -n "$changed" ]; then
        return 0
    fi
    return 1
}

# _count_changed_files_since — count of files modified since marker timestamp.
_count_changed_files_since() {
    local marker="$1"
    local project_dir="${PROJECT_DIR:-.}"
    local log_dir="${LOG_DIR:-${project_dir}/.claude/logs}"
    local count
    count=$(find "$project_dir" -maxdepth "$AGENT_FILE_SCAN_DEPTH" -newer "$marker" \
        -not -path '*/.git/*' \
        -not -path '*/.git' \
        -not -path "${TEKHTON_SESSION_DIR:-/nonexistent}/*" \
        -not -path "${log_dir}/*" \
        -type f 2>/dev/null | count_lines)
    echo "${count:-0}"
}
