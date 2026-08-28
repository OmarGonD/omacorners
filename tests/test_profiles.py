#!/usr/bin/env python3
"""Spec for workspace override inheritance. Keep in lockstep with Actions.js."""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ACTIONS = (ROOT / "Actions.js").read_text(encoding="utf-8")
WS_KEY = re.compile(r"^[1-9][0-9]{0,2}$")
CORNERS = ("topLeft", "topRight", "bottomLeft", "bottomRight")


def normalize_action(value: str) -> str:
    if value in {"none", "lock", "menu", "shutdown", "reboot"}:
        return value
    if value.startswith("app:") and re.match(r"^[A-Za-z0-9][A-Za-z0-9._+-]{0,127}$", value[4:]):
        return value
    return "none"


def resolved(defaults: dict, overrides: dict, ws: str, which: str) -> str:
    over = overrides.get(ws) if WS_KEY.match(ws or "") else None
    if over and which in over:
        return normalize_action(over[which])
    return normalize_action(defaults.get(which, "none"))


class WorkspaceOverrideTests(unittest.TestCase):
    def test_inherit_when_workspace_has_no_map(self):
        defaults = {"topLeft": "menu", "topRight": "none", "bottomLeft": "none", "bottomRight": "lock"}
        self.assertEqual(resolved(defaults, {}, "2", "topLeft"), "menu")
        self.assertEqual(resolved(defaults, {}, "2", "bottomRight"), "lock")

    def test_partial_override(self):
        defaults = {"topLeft": "menu", "topRight": "none", "bottomLeft": "none", "bottomRight": "lock"}
        overrides = {"2": {"topLeft": "app:google-chrome"}}
        self.assertEqual(resolved(defaults, overrides, "2", "topLeft"), "app:google-chrome")
        self.assertEqual(resolved(defaults, overrides, "2", "bottomRight"), "lock")
        self.assertEqual(resolved(defaults, overrides, "1", "topLeft"), "menu")

    def test_explicit_none_overrides_default(self):
        defaults = {"topLeft": "menu", "topRight": "none", "bottomLeft": "none", "bottomRight": "none"}
        overrides = {"3": {"topLeft": "none"}}
        self.assertEqual(resolved(defaults, overrides, "3", "topLeft"), "none")

    def test_rejects_bad_workspace_keys(self):
        self.assertFalse(bool(WS_KEY.match("0")))
        self.assertFalse(bool(WS_KEY.match("-1")))
        self.assertFalse(bool(WS_KEY.match("special")))
        self.assertTrue(bool(WS_KEY.match("2")))
        self.assertTrue(bool(WS_KEY.match("12")))

    def test_js_keeps_the_same_workspace_key_rule(self):
        self.assertIn("/^[1-9][0-9]{0,2}$/", ACTIONS)
        self.assertIn("function resolved(", ACTIONS)
        self.assertIn("function withOverride(", ACTIONS)
        self.assertIn("WORKSPACE_MAP_MAX = 32", ACTIONS)


class ClientMatchTests(unittest.TestCase):
    def test_find_prefers_current_workspace(self):
        import json
        # Import the JS logic via a tiny python replica of findClientAddress
        raw = json.dumps([
            {"class": "google-chrome", "initialClass": "google-chrome", "address": "0xaaaa", "mapped": True, "workspace": {"id": 1}},
            {"class": "google-chrome", "initialClass": "google-chrome", "address": "0xbbbb", "mapped": True, "workspace": {"id": 2}},
        ])
        # Replicate from Actions.js using a subprocess-less parse
        from pathlib import Path
        # execute the matching rules inline
        def find(raw_json, desk, ws):
            data = json.loads(raw_json)
            fallback = ""
            for c in data:
                if str(c.get("class", "")).lower() != desk:
                    continue
                addr = c["address"]
                if str(c.get("workspace", {}).get("id")) == str(ws):
                    return addr
                if not fallback:
                    fallback = addr
            return fallback
        self.assertEqual(find(raw, "google-chrome", "2"), "0xbbbb")
        self.assertEqual(find(raw, "google-chrome", "9"), "0xaaaa")

    def test_js_exports_find_client_address(self):
        self.assertIn("function findClientAddress(", ACTIONS)
        self.assertIn("function isWindowAddress(", ACTIONS)
        self.assertIn("0x[0-9a-fA-F]{4,18}", ACTIONS)


if __name__ == "__main__":
    unittest.main()
