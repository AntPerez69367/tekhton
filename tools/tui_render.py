"""Rendering helpers for tools/tui.py (M98 layout redesign).

Exports:
    _fmt_duration, _build_logo, _build_simple_logo, _build_header_bar,
    _build_events_panel

Imported by tui.py which re-exports these symbols for test discovery.
"""
from __future__ import annotations

import time
from typing import Any

from rich.panel import Panel
from rich.progress_bar import ProgressBar
from rich.table import Table
from rich.text import Text


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


# ---- Logo constants ---------------------------------------------------------
# Five 12-char rows representing a semicircular arch. Row 0 is the keystone
# zone (animates through ghost → floating → seated states); rows 1–4 are the
# arch walls and always present. See milestone doc §5 for the SVG mapping.

_ARCH_WALLS: list[tuple[str, str]] = [
    ("   \u258c    \u2590   ", "white"),    # row 1 crown — voussoir faces
    ("  \u2588\u2588    \u2588\u2588  ", "white"),  # row 2 mid-upper
    (" \u2588\u2588      \u2588\u2588 ", "white"),  # row 3 mid-lower
    ("\u2588\u2588        \u2588\u2588", "white"),  # row 4 base
]
_LOGO_FRAMES: list[tuple[str, str]] = [
    ("    \u2591\u2591\u2591\u2591    ", "dim cyan"),               # ghost
    ("    \u2588\u2588\u2588\u2588    ", "bold bright_cyan"),       # floating
    ("            ", ""),                                           # seated (row 0 empty)
]
_LOGO_FRAME2_CROWN = ("   \u258c\u2588\u2588\u2588\u2588\u2590   ", "bold white")
_LOGO_COMPLETE_ROW0 = ("            ", "")
_LOGO_COMPLETE_CROWN = ("   \u258c\u2588\u2588\u2588\u2588\u2590   ", "bold yellow")
_LOGO_COMPLETE_WALL_STYLE = "yellow"
_LOGO_IDLE_ROW0 = ("            ", "")
_LOGO_IDLE_CROWN = ("   \u258c\u2588\u2588\u2588\u2588\u2590   ", "dim white")
_LOGO_IDLE_WALL_STYLE = "dim white"

_SIMPLE_LOGO_LINES = [
    "     /\\     ",
    "    /  \\    ",
    "   / () \\   ",
    "  /______\\  ",
    " |        | ",
]


def _rows_to_text(rows: list[tuple[str, str]]) -> Text:
    text = Text()
    for i, (chars, style) in enumerate(rows):
        if i > 0:
            text.append("\n")
        if style:
            text.append(chars, style=style)
        else:
            text.append(chars)
    return text


def _build_simple_logo(status: dict[str, Any]) -> Text:
    style = "yellow" if status.get("complete") else "white"
    text = Text()
    for i, line in enumerate(_SIMPLE_LOGO_LINES):
        if i > 0:
            text.append("\n")
        text.append(line, style=style)
    return text


def _build_logo(status: dict[str, Any]) -> Text:
    if status.get("simple_logo"):
        return _build_simple_logo(status)
    if status.get("complete"):
        rows = [_LOGO_COMPLETE_ROW0, _LOGO_COMPLETE_CROWN,
                *[(c, _LOGO_COMPLETE_WALL_STYLE) for c, _ in _ARCH_WALLS[1:]]]
    elif (status.get("current_agent_status") or "idle") == "idle":
        rows = [_LOGO_IDLE_ROW0, _LOGO_IDLE_CROWN,
                *[(c, _LOGO_IDLE_WALL_STYLE) for c, _ in _ARCH_WALLS[1:]]]
    else:
        frame = int(time.time() * 0.6) % 3
        crown = _LOGO_FRAME2_CROWN if frame == 2 else _ARCH_WALLS[0]
        rows = [_LOGO_FRAMES[frame], crown, *_ARCH_WALLS[1:]]
    return _rows_to_text(rows)


# ---- Stage pills ------------------------------------------------------------

_STAGE_PILL_SPEC = {
    "pending":  ("\u25cb", "dim"),           # ○
    "running":  ("\u25b6", "yellow bold"),    # ▶
    "complete": ("\u2713", "green"),         # ✓
    "fail":     ("\u2717", "red"),           # ✗
}


def _stage_state(stage: str, stages_complete: list[dict[str, Any]],
                 current_label: str, current_status: str) -> str:
    for s in stages_complete:
        if (s.get("label") or "").lower() == stage.lower():
            v = (s.get("verdict") or "").upper()
            return "fail" if v in ("FAIL", "FAILED", "BLOCKED") else "complete"
    if stage.lower() == (current_label or "").lower():
        if current_status == "running":
            return "running"
        if current_status == "complete":
            return "complete"
    return "pending"


def _build_stage_pills(status: dict[str, Any]) -> Text:
    # M100: stage_order is populated by get_display_stage_order() in
    # lib/pipeline_order.sh before the sidecar starts. If the JSON hasn't
    # been written yet (very early startup) fall back to numbered placeholders
    # derived from stage_total — never a hardcoded stage list, which would
    # silently mask ordering regressions when the pipeline is reconfigured.
    order = status.get("stage_order") or []
    if not order:
        stage_total = int(status.get("stage_total", 0) or 0)
        if stage_total > 0:
            order = [f"stage-{i + 1}" for i in range(stage_total)]
    stages_complete = status.get("stages_complete") or []
    current_label = status.get("stage_label") or ""
    current_status = status.get("current_agent_status") or "idle"
    text = Text()
    for i, stage in enumerate(order):
        state = _stage_state(stage, stages_complete, current_label, current_status)
        icon, style = _STAGE_PILL_SPEC[state]
        if i > 0:
            text.append("  ")
        text.append(f"{icon} {stage}", style=style)
    return text


# ---- Active-stage bar -------------------------------------------------------

def _model_short(model: str) -> str:
    if not model:
        return ""
    return model[len("claude-"):] if model.startswith("claude-") else model


def _build_active_bar(status: dict[str, Any]) -> Table:
    label = status.get("stage_label") or "\u2014"
    model = _model_short(status.get("agent_model") or "")
    used = int(status.get("agent_turns_used", 0) or 0)
    maxt = int(status.get("agent_turns_max", 0) or 0)
    stage_start_ts = int(status.get("stage_start_ts", 0) or 0)
    if stage_start_ts > 0:
        elapsed = max(0, int(time.time()) - stage_start_ts)
    else:
        elapsed = int(status.get("agent_elapsed_secs", 0) or 0)
    agent_status = status.get("current_agent_status") or "idle"

    grid = Table.grid(padding=(0, 1), expand=False)
    for _ in range(6):
        grid.add_column(no_wrap=True)

    bar_total = max(maxt, 1)
    bar = ProgressBar(total=bar_total, completed=min(used, bar_total), width=12)
    if agent_status == "running":
        spin = "\u280b\u2819\u2839\u2838\u283c\u2834\u2826\u2827\u2807\u280f"
        spinner = Text(
            spin[int(time.time() * 10) % len(spin)] + " Running",
            style="yellow",
        )
    elif agent_status == "complete":
        spinner = Text("\u2713 Complete", style="green")
    else:
        spinner = Text("idle", style="dim")

    turns_str = f"{used}/{maxt}" if maxt else f"{used}"
    grid.add_row(
        Text(label, style="bold"),
        Text(model or "\u2014", style="dim"),
        bar,
        Text(f"{turns_str} turns", style="dim"),
        Text(_fmt_duration(elapsed), style="dim"),
        spinner,
    )
    return grid


# ---- Header bar (logo + context) --------------------------------------------

def _truncate(s: str, limit: int) -> str:
    return s if len(s) <= limit else s[:limit] + "\u2026"


def _build_context(status: dict[str, Any]) -> Table:
    milestone = status.get("milestone") or ""
    title = status.get("milestone_title") or ""
    task = status.get("task") or ""
    run_mode = status.get("run_mode") or "task"
    attempt = status.get("attempt", 1) or 1
    max_attempts = status.get("max_attempts", 1) or 1
    cli_flags = status.get("cli_flags") or ""

    grid = Table.grid(expand=True)
    grid.add_column(no_wrap=False)

    header = Text()
    header.append("TEKHTON", style="bold cyan")
    if milestone:
        header.append(f"  M{milestone}", style="bold white")
    if title:
        header.append(f" \u2014 {_truncate(title, 50)}", style="white")
    grid.add_row(header)

    meta = Text(style="dim")
    meta.append(run_mode)
    meta.append(f"  \u00b7  Pass {attempt}/{max_attempts}")
    if cli_flags:
        meta.append(f"  \u00b7  {cli_flags}")
    grid.add_row(meta)

    if task:
        grid.add_row(Text(f'Task: "{_truncate(task, 60)}"', style="white"))
    else:
        grid.add_row("")

    grid.add_row("")  # blank spacer
    grid.add_row(_build_stage_pills(status))
    grid.add_row(_build_active_bar(status))
    return grid


def _build_header_bar(status: dict[str, Any]) -> Panel:
    logo = _build_logo(status)
    context = _build_context(status)
    outer = Table.grid(expand=True, padding=(0, 1))
    outer.add_column(no_wrap=True, width=14)
    outer.add_column(ratio=1)
    outer.add_row(logo, context)
    clock = time.strftime("%H:%M:%S")
    return Panel(
        outer,
        border_style="cyan",
        padding=(0, 1),
        subtitle=f"[dim]{clock}[/dim]",
        subtitle_align="right",
    )


# ---- Events panel -----------------------------------------------------------

_EVENT_LEVEL_STYLES = {
    "info": "white",
    "warn": "yellow",
    "error": "red",
    "success": "green",
}


def _build_events_panel(status: dict[str, Any], max_lines: int) -> Panel:
    events = status.get("recent_events") or []
    if max_lines > 0:
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
            style = _EVENT_LEVEL_STYLES.get(level, "white")
            grid.add_row(ts, Text(msg, style=style))
    return Panel(grid, title="Recent events", border_style="cyan", padding=(0, 1))
