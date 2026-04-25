"""Tests for _truncate() function in tui_render_common.py.

Verifies:
- _truncate returns unchanged string when length <= limit
- _truncate appends ellipsis and truncates when length > limit
- _truncate handles edge cases: empty string, exactly-at-limit, far-exceeds-limit
- _truncate handles unicode characters correctly
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

# Skip entire module if rich not installed
rich = pytest.importorskip("rich")  # noqa: F841

TOOLS_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(TOOLS_DIR))

import tui_render_common  # noqa: E402


class TestTruncateFunction:
    """Test the _truncate() function."""

    def test_empty_string(self):
        """Empty string returns empty string."""
        result = tui_render_common._truncate("", 32)
        assert result == ""

    def test_string_shorter_than_limit(self):
        """String shorter than limit passes through unchanged."""
        result = tui_render_common._truncate("hello", 32)
        assert result == "hello"

    def test_string_exactly_at_limit(self):
        """String exactly at limit passes through unchanged."""
        s = "a" * 32
        result = tui_render_common._truncate(s, 32)
        assert result == s
        assert len(result) == 32

    def test_string_one_char_over_limit(self):
        """String one char over limit gets truncated with ellipsis."""
        s = "a" * 33
        result = tui_render_common._truncate(s, 32)
        # Implementation returns s[:limit] + "…", so result is limit + 1 chars
        assert result == "a" * 32 + "…"
        assert len(result) == 33  # 32 chars + ellipsis character

    def test_string_far_exceeds_limit(self):
        """String far exceeding limit truncates to limit chars + ellipsis."""
        s = "a" * 100
        result = tui_render_common._truncate(s, 32)
        # Implementation returns s[:limit] + "…", so result is limit + 1 chars
        assert result == "a" * 32 + "…"
        assert len(result) == 33

    def test_long_substage_breadcrumb(self):
        """Long substage breadcrumb like 'wrap-up » running final static analyzer' truncates."""
        # This is the real-world case from the task description
        breadcrumb = "wrap-up » running final static analyzer"
        result = tui_render_common._truncate(breadcrumb, 32)
        # Implementation returns s[:32] + "…", so result is 33 chars
        assert len(result) == 33
        assert result.endswith("…")
        # Should contain at least part of the start
        assert result.startswith("wrap-up")

    def test_truncate_with_special_characters(self):
        """Truncate handles special characters correctly."""
        s = "stage » substage " + "x" * 50
        result = tui_render_common._truncate(s, 32)
        # Result is limit + 1 chars (32 chars + ellipsis)
        assert len(result) == 33
        assert result.endswith("…")

    def test_ellipsis_character_is_unicode(self):
        """The ellipsis character is the unicode ellipsis, not three dots."""
        result = tui_render_common._truncate("a" * 40, 10)
        # Should end with … (U+2026), not "..."
        assert result.endswith("…")
        assert not result.endswith("...")

    def test_limit_of_one(self):
        """Limit of 1 produces one char + ellipsis."""
        result = tui_render_common._truncate("hello", 1)
        # s[:1] + "…" = "h" + "…"
        assert result == "h…"
        assert len(result) == 2

    def test_limit_zero(self):
        """Limit of 0 with non-empty string produces ellipsis."""
        result = tui_render_common._truncate("hello", 0)
        # s[:0] + "…" = "" + "…"
        assert result == "…"
        assert len(result) == 1

    def test_very_long_label(self):
        """Very long label truncates consistently."""
        s = "coder » scout » running bootstrap-compiler"
        result = tui_render_common._truncate(s, 32)
        # Result is limit + 1 chars
        assert len(result) == 33
        assert result.endswith("…")
        # Should not completely lose the beginning
        assert result.startswith("c")

    def test_stage_label_32_char_limit(self):
        """Test realistic stage label with 32-char limit (production setting)."""
        labels = [
            ("intake", "intake"),  # Short: unchanged
            ("coder", "coder"),  # Short: unchanged
            ("review » rework cycle 3", "review » rework cycle 3"),  # 24 chars: unchanged
            ("wrap-up » running final static analyzer", None),  # Long: truncated (check result separately)
            ("security » comprehensive protocol analysis » deep audit", None),  # Very long: truncated
        ]
        for label, expected in labels:
            result = tui_render_common._truncate(label, 32)
            if len(label) <= 32:
                # Short labels pass through unchanged
                assert result == expected, f"Short label {label!r} should be unchanged"
            else:
                # Long labels are truncated to 32 chars + ellipsis
                assert len(result) == 33, f"Label {label!r} truncated to {len(result)} != 33"
                assert result.endswith("…"), f"Long label {label!r} should end with ellipsis"
                # Should start with the original label's beginning
                assert result[:-1] == label[:32], f"Truncated content should match first 32 chars"

    def test_unicode_boundary_handling(self):
        """Truncate handles unicode characters correctly."""
        # Create string with unicode characters
        s = "stage α β γ δ ε ζ η θ ι κ λ μ ν ξ ο π ρ"
        result = tui_render_common._truncate(s, 20)
        # Result should be 20 chars + ellipsis = 21
        assert len(result) == 21
        assert result.endswith("…")
        # Should be decodable without errors
        assert isinstance(result, str)
