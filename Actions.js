.pragma library

// Built-in actions are a closed whitelist. Application launches use
// `app:<desktop-id>` where the desktop id is validated before it is
// persisted or executed. Argv vectors for built-ins are constant.
// App argv is a constant prefix plus that validated id.

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
  "shutdown",
  "reboot",
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
  "shutdown": { label: "Shut down", kind: "argv", argv: ["omarchy-system-shutdown"] },
  "reboot": { label: "Restart", kind: "argv", argv: ["omarchy-system-reboot"] },
  "settings": { label: "Omacorners settings", kind: "argv", argv: ["omarchy-shell", "shell", "toggle", "io.github.omargond.omacorners"] }
}

var DESKTOP_ID_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._+-]{0,127}$/

function isDesktopId(id) {
  if (typeof id !== "string" || id.length === 0 || id.length > 128) return false
  if (id.indexOf("..") !== -1 || id.indexOf("/") !== -1) return false
  return DESKTOP_ID_PATTERN.test(id)
}

function normalizeDesktopId(id) {
  var value = String(id || "").trim()
  if (value.slice(-8) === ".desktop") value = value.slice(0, -8)
  return isDesktopId(value) ? value : ""
}

function isAppAction(id) {
  return typeof id === "string" && id.indexOf("app:") === 0 && isDesktopId(id.substring(4))
}

function desktopIdOf(id) {
  return isAppAction(id) ? id.substring(4) : ""
}

function appAction(desktopId) {
  var id = normalizeDesktopId(desktopId)
  return id ? ("app:" + id) : "none"
}

function isBuiltin(id) {
  return typeof id === "string" && META[id] !== undefined
}

function isAction(id) {
  return isBuiltin(id) || isAppAction(id)
}

function normalize(id) {
  if (isBuiltin(id)) return id
  if (isAppAction(id)) return id
  return "none"
}

function labelOf(id) {
  if (isAppAction(id)) return desktopIdOf(id)
  return META[normalize(id)].label
}

function needsConfirm(id) {
  id = normalize(id)
  return id === "shutdown" || id === "reboot"
}

function confirmMessage(id) {
  if (id === "reboot") return "Restart this computer?"
  if (id === "shutdown") return "Shut down this computer?"
  return ""
}

function confirmLabel(id) {
  if (id === "reboot") return "Restart"
  if (id === "shutdown") return "Shut down"
  return "Confirm"
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
  if (isAppAction(id)) {
    if (typeof execArgv !== "function") return false
    var desktop = desktopIdOf(id)
    if (!desktop) return false
    execArgv(["uwsm-app", "--", "gtk-launch", desktop + ".desktop"])
    return true
  }
  var meta = META[id]
  if (!meta) return false
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
