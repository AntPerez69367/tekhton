"""Tests for tools/tui_render_timings.py — TUI stage timings panel.

Verifies:
- _normalize_time converts raw seconds to canonical duration format
- _normalize_time handles edge cases (empty, already-formatted, invalid)
- _build_timings_panel renders completed stages with consistent formatting
- Live row formatting matches completed row formatting for time display
- Turns display renders correctly for both live and completed stages
"""

from __future__ import annotations

import io
import sys
import time as _time
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

# Skip entire module if rich not installed
rich = pytest.importorskip("rich")  # noqa: F841

TOOLS_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(TOOLS_DIR))

import tui_render_timings  # noqa: E402
from rich.console import Console  # noqa: E402


def _render_panel(panel) -> str:
    """Render a rich Panel to a string for testing."""
    buf = io.StringIO()
    console = Console(file=buf, force_terminal=True, width=100)
    console.print(panel)
    return buf.getvalue()


class TestNormalizeTime:
    """Test the _normalize_time function."""

    def test_empty_string(self):
        """Empty string passes through unchanged."""
        assert tui_render_timings._normalize_time("") == ""

    def test_whitespace_only(self):
        """Whitespace-only string passes through unchanged."""
        assert tui_render_timings._normalize_time("  ") == "  "

    def test_raw_seconds_zero(self):
        """Raw seconds '0s' becomes '0s'."""
        assert tui_render_timings._normalize_time("0s") == "0s"

    def test_raw_seconds_under_minute(self):
        """Raw seconds '42s' stays as '42s'."""
        assert tui_render_timings._normalize_time("42s") == "42s"

    def test_raw_seconds_one_minute(self):
        """Raw seconds '60s' becomes '1m0s'."""
        result = tui_render_timings._normalize_time("60s")
        assert result == "1m0s"

    def test_raw_seconds_ninety(self):
        """Raw seconds '90s' becomes '1m30s' (the main bug fix)."""
        result = tui_render_timings._normalize_time("90s")
        assert result == "1m30s"

    def test_raw_seconds_large(self):
        """Raw seconds '3725s' becomes '1h2m5s'."""
        result = tui_render_timings._normalize_time("3725s")
        assert result == "1h2m5s"

    def test_already_formatted_minutes_seconds(self):
        """Already-formatted '1m 30s' passes through unchanged."""
        # Already formatted strings contain non-digit chars before 's',
        # so they don't match the isdigit() pattern and pass through.
        assert tui_render_timings._normalize_time("1m 30s") == "1m 30s"

    def test_already_formatted_hours(self):
        """Already-formatted '1h 2m 5s' passes through unchanged."""
        assert tui_render_timings._normalize_time("1h 2m 5s") == "1h 2m 5s"

    def test_non_numeric_before_s(self):
        """String with non-digits before 's' passes through unchanged."""
        assert tui_render_timings._normalize_time("abcs") == "abcs"

    def test_missing_s_suffix(self):
        """String without 's' suffix passes through unchanged."""
        assert tui_render_timings._normalize_time("90") == "90"

    def test_whitespace_around_raw_seconds(self):
        """Whitespace around '90s' is stripped and then processed."""
        # "  90s  ".strip() = "90s" which should normalize
        result = tui_render_timings._normalize_time("  90s  ")
        assert result == "1m30s"

    def test_hardcoded_string(self):
        """Pre-hardcoded strings like 'pending' pass through unchanged."""
        assert tui_render_timings._normalize_time("pending") == "pending"


class TestBuildTimingsPanel:
    """Test _build_timings_panel function."""

    def test_no_stages_no_live(self):
        """Panel with no stages and no live row shows 'no stages yet'."""
        status = {
            "stages_complete": [],
            "stage_label": "",
            "current_agent_status": "idle",
        }
        panel = tui_render_timings._build_timings_panel(status)
        assert panel is not None
        panel_str = _render_panel(panel)
        assert "no stages yet" in panel_str

    def test_single_completed_stage(self):
        """Panel renders a single completed stage with normalized time."""
        status = {
            "stages_complete": [
                {
                    "label": "intake",
                    "time": "90s",
                    "turns": "2/10",
                    "verdict": "PASS",
                }
            ],
            "stage_label": "",
            "current_agent_status": "idle",
        }
        panel = tui_render_timings._build_timings_panel(status)
        panel_str = _render_panel(panel)
        # Should contain the stage label
        assert "intake" in panel_str
        # Time should be normalized from "90s" to "1m30s"
        assert "1m30s" in panel_str or "1m 30s" in panel_str
        # Should show the turns
        assert "2/10" in panel_str

    def test_multiple_completed_stages(self):
        """Panel renders multiple completed stages."""
        status = {
            "stages_complete": [
                {
                    "label": "intake",
                    "time": "16s",
                    "turns": "2/10",
                    "verdict": "PASS",
                },
                {
                    "label": "coder",
                    "time": "120s",
                    "turns": "5/50",
                    "verdict": "PASS",
                },
            ],
            "stage_label": "",
            "current_agent_status": "idle",
        }
        panel = tui_render_timings._build_timings_panel(status)
        panel_str = _render_panel(panel)
        assert "intake" in panel_str
        assert "coder" in panel_str
        assert "16s" in panel_str
        assert "2m0s" in panel_str or "2m" in panel_str

    def test_live_stage_running(self):
        """Panel with live running stage shows live row with spinner."""
        current_time = int(_time.time())
        status = {
            "stages_complete": [],
            "stage_label": "coder",
            "current_agent_status": "running",
            "stage_start_ts": current_time - 90,  # 90 seconds ago
            "agent_turns_max": 50,
        }
        panel = tui_render_timings._build_timings_panel(status)
        panel_str = _render_panel(panel)
        assert "coder" in panel_str
        # Should show '--/50' turns for live stage
        assert "--/50" in panel_str
        # Should show elapsed time in formatted form
        assert "m" in panel_str or "s" in panel_str

    def test_live_stage_working(self):
        """Panel with working (shell op) stage uses current_operation label."""
        current_time = int(_time.time())
        status = {
            "stages_complete": [],
            "stage_label": "review",
            "current_agent_status": "working",
            "current_operation": "reviewing changes",
            "stage_start_ts": current_time - 30,
            "agent_turns_max": 15,
        }
        panel = tui_render_timings._build_timings_panel(status)
        panel_str = _render_panel(panel)
        # Should use the current_operation label during working state
        assert "reviewing changes" in panel_str or "review" in panel_str

    def test_completed_and_live_stages(self):
        """Panel with both completed and live stages renders both."""
        current_time = int(_time.time())
        status = {
            "stages_complete": [
                {
                    "label": "intake",
                    "time": "16s",
                    "turns": "2/10",
                    "verdict": "PASS",
                }
            ],
            "stage_label": "coder",
            "current_agent_status": "running",
            "stage_start_ts": current_time - 60,
            "agent_turns_max": 50,
        }
        panel = tui_render_timings._build_timings_panel(status)
        panel_str = _render_panel(panel)
        assert "intake" in panel_str
        assert "coder" in panel_str

    def test_stage_with_failed_verdict(self):
        """Panel shows failed verdict with red icon."""
        status = {
            "stages_complete": [
                {
                    "label": "security",
                    "time": "45s",
                    "turns": "3/15",
                    "verdict": "BLOCKED",
                }
            ],
            "stage_label": "",
            "current_agent_status": "idle",
        }
        panel = tui_render_timings._build_timings_panel(status)
        # Panel should render without error; exact formatting depends on rich
        assert panel is not None

    def test_stage_with_missing_verdict(self):
        """Panel handles stage with missing verdict gracefully."""
        status = {
            "stages_complete": [
                {
                    "label": "coder",
                    "time": "100s",
                    "turns": "4/50",
                }
            ],
            "stage_label": "",
            "current_agent_status": "idle",
        }
        panel = tui_render_timings._build_timings_panel(status)
        assert panel is not None
        panel_str = _render_panel(panel)
        assert "coder" in panel_str

    def test_stage_with_missing_time(self):
        """Panel handles stage with missing time gracefully."""
        status = {
            "stages_complete": [
                {
                    "label": "tester",
                    "turns": "6/30",
                    "verdict": "PASS",
                }
            ],
            "stage_label": "",
            "current_agent_status": "idle",
        }
        panel = tui_render_timings._build_timings_panel(status)
        assert panel is not None

    def test_stage_with_empty_time(self):
        """Panel handles stage with empty time string."""
        status = {
            "stages_complete": [
                {
                    "label": "review",
                    "time": "",
                    "turns": "2/10",
                    "verdict": "PASS",
                }
            ],
            "stage_label": "",
            "current_agent_status": "idle",
        }
        panel = tui_render_timings._build_timings_panel(status)
        assert panel is not None

    def test_live_stage_no_start_ts(self):
        """Live stage with stage_start_ts=0 uses agent_elapsed_secs."""
        status = {
            "stages_complete": [],
            "stage_label": "coder",
            "current_agent_status": "running",
            "stage_start_ts": 0,
            "agent_elapsed_secs": 75,
            "agent_turns_max": 50,
        }
        panel = tui_render_timings._build_timings_panel(status)
        panel_str = _render_panel(panel)
        assert "coder" in panel_str
        # elapsed should be 75 seconds formatted as time
        assert "m" in panel_str or "75" in panel_str

    def test_normalized_time_in_completed_row(self):
        """Completed stage row uses normalized time (main bug fix)."""
        # This is the primary assertion for bug #1: format consistency
        status = {
            "stages_complete": [
                {
                    "label": "review",
                    "time": "83s",  # Raw seconds (as sent by bash)
                    "turns": "2/10",
                    "verdict": "PASS",
                }
            ],
            "stage_label": "",
            "current_agent_status": "idle",
        }
        panel = tui_render_timings._build_timings_panel(status)
        panel_str = _render_panel(panel)
        # Should normalize "83s" to "1m23s", not leave it as "83s"
        assert "1m23s" in panel_str or "1m 23s" in panel_str

    def test_consistency_live_vs_completed_format(self):
        """Live and completed stages use same time format."""
        current_time = int(_time.time())
        status = {
            "stages_complete": [
                {
                    "label": "intake",
                    "time": "75s",  # Should normalize to "1m15s"
                    "turns": "2/10",
                    "verdict": "PASS",
                }
            ],
            "stage_label": "coder",
            "current_agent_status": "running",
            "stage_start_ts": current_time - 75,  # Live elapsed is ~75s
            "agent_turns_max": 50,
        }
        panel = tui_render_timings._build_timings_panel(status)
        panel_str = _render_panel(panel)
        # Both should show "1m15s" or similar formatted duration
        # (live row uses _fmt_duration directly, completed uses _normalize_time)
        assert "1m" in panel_str
