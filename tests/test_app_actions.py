#!/usr/bin/env python3
"""Spec for app:<desktop-id> actions. Keep in lockstep with Actions.js."""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ACTIONS = (ROOT / "Actions.js").read_text(encoding="utf-8")

DESKTOP_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._+-]{0,127}$")


def is_desktop_id(value: str) -> bool:
    if not value or len(value) > 128:
        return False
    if ".." in value or "/" in value:
        return False
    return bool(DESKTOP_ID.match(value))


def normalize_desktop_id(value: str) -> str:
    value = str(value or "").strip()
    if value.endswith(".desktop"):
        value = value[:-8]
    return value if is_desktop_id(value) else ""


def is_app_action(value: str) -> bool:
    return value.startswith("app:") and is_desktop_id(value[4:])


class AppActionTests(unittest.TestCase):
    def test_accepts_chrome_ids(self):
        for desk in ("google-chrome", "com.google.Chrome", "chromium"):
            self.assertTrue(is_desktop_id(desk), desk)
            self.assertTrue(is_app_action("app:" + desk), desk)
            self.assertEqual(normalize_desktop_id(desk + ".desktop"), desk)

    def test_rejects_path_and_shell_payloads(self):
        for bad in (
            "../etc/passwd",
            "foo/bar",
            "foo;rm",
            "foo bar",
            "foo$(id)",
            "foo`id`",
            "",
            "app:",
        ):
            self.assertFalse(is_desktop_id(bad), bad)
            self.assertFalse(is_app_action("app:" + bad) if bad else is_app_action("app:"), bad)

    def test_js_keeps_the_same_desktop_id_pattern(self):
        self.assertIn(r"/^[A-Za-z0-9][A-Za-z0-9._+-]{0,127}$/", ACTIONS)
        self.assertIn('id.indexOf("..") !== -1', ACTIONS)
        self.assertIn('id.indexOf("/") !== -1', ACTIONS)
        self.assertIn("app:", ACTIONS)

    def test_power_actions_are_confirm_gated(self):
        self.assertRegex(ACTIONS, r"function needsConfirm[\s\S]+shutdown[\s\S]+reboot")


if __name__ == "__main__":
    unittest.main()
