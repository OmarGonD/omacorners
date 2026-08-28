# Omacorners

**macOS-style hot corners for [Omarchy](https://omarchy.org/).**

Move the pointer into a screen corner, wait the dwell delay, and Omarchy runs
the action you assigned: lock, screensaver, show desktop, menu, notifications,
clipboard, screenshot, and more.

![Omacorners settings overlay](preview.png)

---

## Features

* **Per-corner actions.** Top-left, top-right, bottom-left, bottom-right, each
  independently assigned from a fixed whitelist.
* **Dwell delay.** Default 400ms, 0–2s. Corners set to None never fire, so you
  can keep a pass-through path between monitors.
* **Corner glow.** An accent blob grows at the corner while you dwell, then
  pulses when the action runs. Click-through overlay — it never steals input.
* **Show desktop.** Toggles an empty Hyprland special workspace named
  `omacorners`, so windows stay where they were.
* **Settings overlay.** Visual screen diagram, four dropdowns, delay and
  corner-size sliders, and a pause toggle that keeps your assignments.

## Install

```bash
omarchy plugin add https://github.com/OmarGonD/omacorners.git --enable
omarchy restart shell
```

Open settings:

```bash
omarchy-shell shell toggle io.github.omargond.omacorners
```

Or from the Omarchy menu, add this to
`~/.config/omarchy/extensions/omarchy-menu.jsonc`:

```jsonc
"setup.omacorners": {
  "icon": "󰝥",
  "label": "Omacorners",
  "aliases": ["hotcorners", "hot-corners", "omacorners"],
  "description": "Assign an action to each screen corner",
  "action": "omarchy-shell shell toggle io.github.omargond.omacorners"
}
```

A keybind, if you want one, in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + H", "Omacorners", "omarchy-shell shell toggle io.github.omargond.omacorners")
```

## Enable or Disable

```bash
omarchy plugin enable io.github.omargond.omacorners
omarchy plugin disable io.github.omargond.omacorners
```

The settings overlay also has an **Enabled** switch that pauses corner
detection without dropping your assignments.

## Remove

```bash
omarchy plugin remove io.github.omargond.omacorners
```

Deletes the plugin checkout and its `shell.json` entry. Menu rows or
keybindings you added by hand are left in place.

## Actions

| Action | What it runs |
|---|---|
| None | — |
| Lock screen | `omarchy-system-lock` |
| Screensaver | `omarchy-launch-screensaver force` |
| Show desktop | `hyprctl dispatch togglespecialworkspace omacorners` |
| Omarchy menu | `omarchy-menu toggle` |
| Notification history | `omarchy-shell notifications showHistory` |
| Clipboard history | `omarchy-shell shell toggle omarchy.clipboard` |
| Emoji picker | `omarchy-shell shell toggle omarchy.emojis` |
| Screenshot | `omarchy-capture-screenshot` |
| Color picker | `hyprpicker -a` |
| Do not disturb | `omarchy-toggle-notification-silencing` |
| Night light | `omarchy-toggle-nightlight` |
| Toggle bar | `omarchy-toggle-bar` |
| Terminal | `omarchy-launch-terminal` |
| Browser | `omarchy-launch-browser` |
| Next / previous workspace | `workspace e+1` / `workspace e-1` |
| Omacorners settings | this overlay |

Unknown values in `shell.json` normalize to **None**. There is no free-form
command field.

## Settings

Stored on the plugin's entry in `~/.config/omarchy/shell.json`:

| Key | Default | Meaning |
|---|---|---|
| `active` | `true` | Master switch |
| `delayMs` | `400` | Dwell time, 0–2000 |
| `thresholdPx` | `8` | Corner hit size in layout pixels, 2–48 |
| `topLeft` / `topRight` / `bottomLeft` / `bottomRight` | `none` | Action ids from the table above |

IPC for debugging: `omarchy-shell omacorners status`

## Architecture & Security

* **No extra permissions.** The helper talks only to Hyprland's local request
  socket (`$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock`)
  for `cursorpos` and `j/monitors`. It never opens `/dev/input`, never injects
  input, and never uses `sudo` / `pkexec`.
* **No network.** No HTTP, no analytics, no remote dependencies.
* **No shell interpolation.** Every action is a constant argv vector or a
  constant Hyprland dispatcher string. User-edited action ids that are not on
  the whitelist become `none`.
* **Click-through glow.** The per-monitor overlay uses an empty input region
  (`mask: Region {}`) so it cannot eat clicks.
* **Cursor coordinates** exist only in memory while the helper is running.
  They are not logged, persisted, or sent anywhere.

The plugin runs unsandboxed inside `omarchy-shell`, like every Omarchy plugin.
Read `Omacorners.qml`, `Actions.js`, `Corners.js`, `Settings.qml`, and
`scripts/omacorners-cursor` before enabling.

## Requirements

* Omarchy 4.x with Quickshell
* Hyprland (the running compositor)
* `python3` (standard library only)

## Development

```bash
tests/run-tests.sh
omarchy plugin validate .
```

Symlink into the live plugin dir and restart the shell after edits:

```bash
ln -sfn "$PWD" ~/.config/omarchy/plugins/io.github.omargond.omacorners
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.omargond.omacorners
omarchy restart shell
```

## License

MIT
