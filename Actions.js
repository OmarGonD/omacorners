.pragma library

// Whitelist of hot-corner actions. Ids that are not in META normalize to
// "none". Argv vectors are constant; Hyprland dispatch strings are constant.
// Nothing here is interpolated from user input.

var ORDER = [
  "none",
  "lock",
  "screensaver",
  "desktop",
  "menu",
  "notifications",
  "clipboard",
  "emojis",
  "screenshot",
  "color",
  "dnd",
  "nightlight",
  "bar",
  "terminal",
  "browser",
  "workspace-next",
  "workspace-prev",
  "settings"
]

var META = {
  "none": { label: "None", kind: "none" },
  "lock": { label: "Lock screen", kind: "argv", argv: ["omarchy-system-lock"] },
  "screensaver": { label: "Screensaver", kind: "argv", argv: ["omarchy-launch-screensaver", "force"] },
  "desktop": { label: "Show desktop", kind: "hypr", dispatch: "togglespecialworkspace omacorners" },
  "menu": { label: "Omarchy menu", kind: "argv", argv: ["omarchy-menu", "toggle"] },
  "notifications": { label: "Notification history", kind: "argv", argv: ["omarchy-shell", "notifications", "showHistory"] },
  "clipboard": { label: "Clipboard history", kind: "argv", argv: ["omarchy-shell", "shell", "toggle", "omarchy.clipboard"] },
  "emojis": { label: "Emoji picker", kind: "argv", argv: ["omarchy-shell", "shell", "toggle", "omarchy.emojis"] },
  "screenshot": { label: "Screenshot", kind: "argv", argv: ["omarchy-capture-screenshot"] },
  "color": { label: "Color picker", kind: "argv", argv: ["hyprpicker", "-a"] },
  "dnd": { label: "Do not disturb", kind: "argv", argv: ["omarchy-toggle-notification-silencing"] },
  "nightlight": { label: "Night light", kind: "argv", argv: ["omarchy-toggle-nightlight"] },
  "bar": { label: "Toggle bar", kind: "argv", argv: ["omarchy-toggle-bar"] },
  "terminal": { label: "Terminal", kind: "argv", argv: ["omarchy-launch-terminal"] },
  "browser": { label: "Browser", kind: "argv", argv: ["omarchy-launch-browser"] },
  "workspace-next": { label: "Next workspace", kind: "hypr", dispatch: "workspace e+1" },
  "workspace-prev": { label: "Previous workspace", kind: "hypr", dispatch: "workspace e-1" },
  "settings": { label: "Omacorners settings", kind: "argv", argv: ["omarchy-shell", "shell", "toggle", "io.github.omargond.omacorners"] }
}

function isAction(id) {
  return typeof id === "string" && META[id] !== undefined
}

function normalize(id) {
  return isAction(id) ? id : "none"
}

function labelOf(id) {
  return META[normalize(id)].label
}

function options() {
  var out = []
  for (var i = 0; i < ORDER.length; i++) {
    var id = ORDER[i]
    out.push({ value: id, label: META[id].label })
  }
  return out
}

function run(id, hyprDispatch, execArgv) {
  id = normalize(id)
  if (id === "none") return false
  var meta = META[id]
  if (meta.kind === "hypr") {
    if (typeof hyprDispatch !== "function") return false
    hyprDispatch(String(meta.dispatch))
    return true
  }
  if (meta.kind === "argv") {
    if (typeof execArgv !== "function" || !meta.argv) return false
    execArgv(meta.argv.slice())
    return true
  }
  return false
}
