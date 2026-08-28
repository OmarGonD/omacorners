#!/usr/bin/env python3
"""Spec for Corners.js hit testing. Keep this algorithm in lockstep with Corners.js."""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def clamp_threshold(value):
    try:
        n = float(value)
    except (TypeError, ValueError):
        return 2
    if n != n:  # NaN
        return 2
    return int(round(max(2, min(48, n))))


def hit_on_screen(sx, sy, sw, sh, x, y, threshold):
    t = clamp_threshold(threshold)
    if sw <= 0 or sh <= 0:
        return ""
    if x < sx or y < sy or x >= sx + sw or y >= sy + sh:
        return ""
    left = x - sx <= t
    right = (sx + sw) - x <= t
    top = y - sy <= t
    bottom = (sy + sh) - y <= t
    if top and left:
        return "tl"
    if top and right:
        return "tr"
    if bottom and left:
        return "bl"
    if bottom and right:
        return "br"
    return ""


def hit(screens, x, y, threshold):
    for s in screens[:16]:
        corner = hit_on_screen(s["x"], s["y"], s["width"], s["height"], x, y, threshold)
        if corner:
            return {"corner": corner, "name": s.get("name", "")}
    return None


class CornerHitTests(unittest.TestCase):
    def test_single_monitor_corners(self):
        s = [{"name": "A", "x": 0, "y": 0, "width": 1720, "height": 720}]
        self.assertEqual(hit(s, 0, 0, 8)["corner"], "tl")
        self.assertEqual(hit(s, 1719, 0, 8)["corner"], "tr")
        self.assertEqual(hit(s, 0, 719, 8)["corner"], "bl")
        self.assertEqual(hit(s, 1719, 719, 8)["corner"], "br")
        self.assertIsNone(hit(s, 860, 360, 8))

    def test_threshold_band(self):
        s = [{"name": "A", "x": 0, "y": 0, "width": 100, "height": 80}]
        self.assertEqual(hit_on_screen(0, 0, 100, 80, 8, 8, 8), "tl")
        self.assertEqual(hit_on_screen(0, 0, 100, 80, 9, 9, 8), "")
        self.assertEqual(hit_on_screen(0, 0, 100, 80, 92, 8, 8), "tr")

    def test_shared_edge_belongs_to_the_next_monitor(self):
        screens = [
            {"name": "L", "x": 0, "y": 0, "width": 100, "height": 80},
            {"name": "R", "x": 100, "y": 0, "width": 100, "height": 80},
        ]
        # Half-open right edge: x=100 is on the right monitor, not L's tr.
        self.assertEqual(hit(screens, 99, 0, 8)["name"], "L")
        self.assertEqual(hit(screens, 99, 0, 8)["corner"], "tr")
        self.assertEqual(hit(screens, 100, 0, 8)["name"], "R")
        self.assertEqual(hit(screens, 100, 0, 8)["corner"], "tl")

    def test_outside_is_a_miss(self):
        s = [{"name": "A", "x": 10, "y": 10, "width": 50, "height": 50}]
        self.assertIsNone(hit(s, 9, 10, 8))
        self.assertIsNone(hit(s, 10, 9, 8))
        self.assertEqual(hit_on_screen(10, 10, 50, 50, 10, 10, 8), "tl")

    def test_js_still_uses_the_same_half_open_test(self):
        src = (ROOT / "Corners.js").read_text(encoding="utf-8")
        self.assertIn("x >= sx + sw || y >= sy + sh", src)
        self.assertIn('(sx + sw) - x <= t', src)
        self.assertIn("if (n > 16) n = 16", src)

    def test_delay_and_threshold_clamps_exist(self):
        src = (ROOT / "Corners.js").read_text(encoding="utf-8")
        self.assertRegex(src, re.compile(r"clampDelayMs[\s\S]{0,80}2000"))
        self.assertRegex(src, re.compile(r"clampThresholdPx[\s\S]{0,80}48"))


if __name__ == "__main__":
    unittest.main()
