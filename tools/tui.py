#!/usr/bin/env python3
"""Tekhton TUI sidecar: reads tui_status.json and renders a rich.live layout.

Runs as a background process spawned by lib/tui.sh. Reads the status file on a
tick, re-renders, and exits when the status file marks complete=true or when
the parent kills it (SIGTERM/SIGINT).
"""

from __future__ import annotations

import argparse
import json
import signal
import sys
import time
from pathlib import Path
from typing import Any

from rich.console import Console
from rich.layout import Layout
from rich.live import Live
from rich.panel import Panel
from rich.progress_bar import ProgressBar
from rich.table import Table
from rich.text import Text

_STOP = False


def _handle_signal(_signum, _frame):
    global _STOP
    _STOP = True


def _fmt_duration(secs: int) -> str:
    if secs <= 0:
        return "0s"
    hours, rem = divmod(int(secs), 3600)
    mins, s = divmod(rem, 60)
    if hours:
        return f"{hours}h{mins}m{s}s"
    if mins:
        return f"{mins}m{s}s"
    return f"{s}s"


def _read_status(path: Path) -> dict[str, Any] | None:
    try:
        raw = path.read_text(encoding="utf-8")
    except (FileNotFoundError, OSError):
        return None
    if not raw.strip():
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return None


def _build_header(status: dict[str, Any]) -> Panel:
    milestone = status.get("milestone") or "?"
    title = status.get("milestone_title") or status.get("task") or ""
    clock = time.strftime("%H:%M:%S")
    text = Text()
    text.append("Tekhton  ", style="bold cyan")
    text.append(f"M{milestone}", style="bold white")
    if title:
        text.append(f" — {title}", style="white")
    pad = max(1, 50 - len(title))
    text.append(" " * pad)
    text.append(clock, style="dim")
    return Panel(text, border_style="cyan", padding=(0, 1))


def _build_stage_panel(status: dict[str, Any]) -> Panel:
    label = status.get("stage_label") or "—"
    num = status.get("stage_num", 0) or 0
    total = status.get("stage_total", 0) or 0
    model = status.get("agent_model") or ""
    used = int(status.get("agent_turns_used", 0) or 0)
    maxt = int(status.get("agent_turns_max", 0) or 0)
    # Compute elapsed from stage_start_ts so the timer ticks on every
    # render cycle — even during non-agent phases like prerun test checks.
    stage_start_ts = int(status.get("stage_start_ts", 0) or 0)
    if stage_start_ts > 0:
        elapsed = max(0, int(time.time()) - stage_start_ts)
    else:
        elapsed = int(status.get("agent_elapsed_secs", 0) or 0)
    agent_status = status.get("current_agent_status", "idle")

    grid = Table.grid(padding=(0, 1))
    grid.add_column(no_wrap=True)
    stage_line = f"Stage {num} / {total} — {label}" if total else label
    grid.add_row(Text(stage_line, style="bold"))
    if model:
        grid.add_row(Text(model, style="dim"))
    grid.add_row("")

    bar_total = max(maxt, 1)
    bar = ProgressBar(total=bar_total, completed=min(used, bar_total), width=20)
    turns_text = Text()
    turns_text.append("Turns   ")
    turns_row = Table.grid(padding=(0, 1))
    turns_row.add_column(no_wrap=True)
    turns_row.add_column(no_wrap=True)
    turns_row.add_column(no_wrap=True)
    turns_row.add_row("Turns", bar, f"{used}/{maxt}" if maxt else f"{used}")
    grid.add_row(turns_row)

    grid.add_row(Text(f"Time    {_fmt_duration(elapsed)}"))

    if agent_status == "running":
        spin_frames = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
        frame = spin_frames[int(time.time() * 10) % len(spin_frames)]
        grid.add_row(Text(f"{frame} Running...", style="yellow"))
    elif agent_status == "complete":
        grid.add_row(Text("✓ Complete", style="green"))
    else:
        grid.add_row(Text("idle", style="dim"))

    return Panel(grid, title="Current stage", border_style="blue", padding=(0, 1))


def _build_pipeline_panel(status: dict[str, Any]) -> Panel:
    elapsed = int(status.get("pipeline_elapsed_secs", 0) or 0)
    attempt = status.get("attempt", 1) or 1
    max_attempts = status.get("max_attempts", 1) or 1
    stages = status.get("stages_complete", []) or []

    grid = Table.grid(padding=(0, 1))
    grid.add_column(no_wrap=True)
    grid.add_row(Text(f"Elapsed:   {_fmt_duration(elapsed)}"))
    grid.add_row(Text(f"Attempt:   {attempt} / {max_attempts}"))
    grid.add_row("")
    grid.add_row(Text(f"Stages complete: {len(stages)}", style="bold"))
    for s in stages:
        label = s.get("label", "?")
        tm = s.get("time", "")
        verdict = s.get("verdict")
        mark = "✓"
        style = "green"
        if verdict and verdict.upper() in ("FAIL", "BLOCKED"):
            mark = "✗"
            style = "red"
        grid.add_row(Text(f"  {label:<8} {mark}  {tm}", style=style))
    return Panel(grid, title="Pipeline", border_style="blue", padding=(0, 1))


def _build_events_panel(status: dict[str, Any], max_lines: int) -> Panel:
    events = status.get("recent_events", []) or []
    events = events[-max_lines:]
    grid = Table.grid(padding=(0, 1))
    grid.add_column(no_wrap=True, style="dim")
    grid.add_column(no_wrap=False)
    if not events:
        grid.add_row("", Text("(no events yet)", style="dim italic"))
    else:
        for ev in events:
            ts = ev.get("ts", "")
            level = ev.get("level", "info")
            msg = ev.get("msg", "")
            style = {
                "info": "white",
                "warn": "yellow",
                "error": "red",
                "success": "green",
            }.get(level, "white")
            grid.add_row(ts, Text(msg, style=style))
    return Panel(grid, title="Recent events", border_style="cyan", padding=(0, 1))


def _build_layout(status: dict[str, Any], event_lines: int) -> Layout:
    layout = Layout()
    layout.split_column(
        Layout(name="header", size=3),
        Layout(name="middle", ratio=1),
        Layout(name="events", size=event_lines + 2),
    )
    layout["middle"].split_row(
        Layout(name="stage", ratio=1),
        Layout(name="pipeline", ratio=1),
    )
    layout["header"].update(_build_header(status))
    layout["stage"].update(_build_stage_panel(status))
    layout["pipeline"].update(_build_pipeline_panel(status))
    layout["events"].update(_build_events_panel(status, event_lines))
    return layout


def _empty_status() -> dict[str, Any]:
    return {
        "version": 1,
        "milestone": "",
        "milestone_title": "Starting...",
        "stage_label": "",
        "stage_num": 0,
        "stage_total": 0,
        "agent_turns_used": 0,
        "agent_turns_max": 0,
        "agent_elapsed_secs": 0,
        "stage_start_ts": 0,
        "pipeline_elapsed_secs": 0,
        "stages_complete": [],
        "current_agent_status": "idle",
        "recent_events": [],
        "complete": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--status-file", required=True, type=Path)
    parser.add_argument("--tick-ms", type=int, default=500)
    parser.add_argument("--event-lines", type=int, default=8)
    args = parser.parse_args()

    signal.signal(signal.SIGTERM, _handle_signal)
    signal.signal(signal.SIGINT, _handle_signal)

    tick = max(0.05, args.tick_ms / 1000.0)
    event_lines = max(3, args.event_lines)

    # Always write to the controlling terminal directly (/dev/tty) so the
    # rich display appears even when the parent shell has redirected fd 1
    # (e.g. to a sidecar log file).  Fall back to stdout if /dev/tty is
    # unavailable — the caller already verified the terminal is interactive.
    try:
        _tty = open("/dev/tty", "w")  # noqa: WPS515 — must stay open for sidecar lifetime
        console = Console(file=_tty, force_terminal=True)
    except OSError:
        console = Console(force_terminal=True)
    with Live(
        _build_layout(_empty_status(), event_lines),
        console=console,
        refresh_per_second=max(1, int(1 / tick)),
        screen=True,
        transient=True,
    ) as live:
        while not _STOP:
            status = _read_status(args.status_file) or _empty_status()
            try:
                live.update(_build_layout(status, event_lines))
            except Exception:  # noqa: BLE001 - render failures must not crash sidecar
                pass
            if status.get("complete"):
                time.sleep(tick)
                break
            time.sleep(tick)
    return 0


if __name__ == "__main__":
    sys.exit(main())
