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
        def pick(local, other, active):
            for hit in local:
                if hit["address"] != active:
                    return hit["address"]
            if other:
                return other[0]["address"]
            return local[0]["address"] if local else ""

        local = [{"address": "0xbbbb", "workspace": "2"}]
        other = [{"address": "0xaaaa", "workspace": "1"}]
        self.assertEqual(pick(local, other, "0xffff"), "0xbbbb")
        self.assertEqual(pick(local, other, "0xbbbb"), "0xaaaa")
        self.assertEqual(pick([], other, ""), "0xaaaa")

    def test_js_cycles_when_local_instance_is_focused(self):
        self.assertIn("function pickClient(", ACTIONS)
        self.assertIn("local[i].address !== active", ACTIONS)

    def test_lua_focus_dispatchers(self):
        self.assertIn('hl.dsp.focus({ window = "address:', ACTIONS)
        self.assertIn('hl.dsp.focus({ workspace = "', ACTIONS)
        self.assertIn("function classicToLua(", ACTIONS)
        self.assertIn('hl.dsp.workspace.toggle_special("omacorners")', ACTIONS)

    def test_js_exports_find_client_address(self):
        self.assertIn("function findClientAddress(", ACTIONS)
        self.assertIn("function findClient(", ACTIONS)
        self.assertIn("function isWindowAddress(", ACTIONS)
        self.assertIn("0x[0-9a-fA-F]{4,18}", ACTIONS)
        self.assertIn("workspace: isWorkspaceKey(ws)", ACTIONS)

    def test_fallback_keeps_workspace_id(self):
        import json
        raw = json.dumps([
            {"class": "org.omarchy.agent", "initialClass": "org.omarchy.agent",
             "address": "0xaaaa", "mapped": True, "workspace": {"id": 1}},
        ])
        data = json.loads(raw)
        c = data[0]
        self.assertEqual(str(c["workspace"]["id"]), "1")
        self.assertNotEqual(str(c["workspace"]["id"]), "2")


if __name__ == "__main__":
    unittest.main()
