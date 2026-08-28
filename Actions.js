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
  "agent",
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
  "agent": { label: "Grok", kind: "argv", argv: ["omarchy-agent"], focusClass: "org.omarchy.agent" },
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

var CORNERS = ["topLeft", "topRight", "bottomLeft", "bottomRight"]
var WORKSPACE_KEY = /^[1-9][0-9]{0,2}$/
var WORKSPACE_MAP_MAX = 32

function clampPowerDelayMs(value) {
  var n = Number(value)
  if (!isFinite(n)) return 800
  if (n < 0) return 0
  if (n > 2000) return 2000
  return Math.round(n)
}

function workspaceKeyFrom(ws) {
  if (!ws) return ""
  var id = Number(ws.id)
  if (!isFinite(id) || id < 1 || id > 999) return ""
  return String(Math.round(id))
}

function isWorkspaceKey(key) {
  return typeof key === "string" && WORKSPACE_KEY.test(key)
}

function normalizeWorkspaceMap(raw) {
  var out = {}
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return out
  var keys = []
  for (var key in raw) {
    if (!raw.hasOwnProperty(key)) continue
    keys.push(key)
  }
  if (keys.length > WORKSPACE_MAP_MAX) keys = keys.slice(0, WORKSPACE_MAP_MAX)
  for (var i = 0; i < keys.length; i++) {
    var k = keys[i]
    if (!isWorkspaceKey(k)) continue
    var rec = raw[k]
    if (!rec || typeof rec !== "object") continue
    var cleaned = {}
    var any = false
    for (var c = 0; c < CORNERS.length; c++) {
      var which = CORNERS[c]
      if (rec[which] === undefined || rec[which] === null || rec[which] === "") continue
      cleaned[which] = normalize(rec[which])
      any = true
    }
    if (any) out[k] = cleaned
  }
  return out
}

function resolved(defaults, map, wsKey, which) {
  var over = map && isWorkspaceKey(wsKey) ? map[wsKey] : null
  if (over && over[which] !== undefined) return normalize(over[which])
  return normalize(defaults ? defaults[which] : "none")
}

function hasOverride(map, wsKey) {
  return !!(map && isWorkspaceKey(wsKey) && map[wsKey])
}

function isOverridden(map, wsKey, which) {
  var over = map && isWorkspaceKey(wsKey) ? map[wsKey] : null
  return !!(over && over[which] !== undefined)
}

function withOverride(map, wsKey, which, action) {
  var next = normalizeWorkspaceMap(map)
  if (!isWorkspaceKey(wsKey)) return next
  var rec = next[wsKey] ? next[wsKey] : {}
  var copy = {}
  for (var i = 0; i < CORNERS.length; i++) {
    var c = CORNERS[i]
    if (rec[c] !== undefined) copy[c] = rec[c]
  }
  copy[which] = normalize(action)
  next[wsKey] = copy
  return next
}

function withoutWorkspace(map, wsKey) {
  var next = normalizeWorkspaceMap(map)
  if (next[wsKey]) delete next[wsKey]
  return next
}

function entryIsThin(entry) {
  if (!entry || typeof entry !== "object") return true
  for (var k in entry) {
    if (!entry.hasOwnProperty(k)) continue
    if (k === "id") continue
    return false
  }
  return true
}

function focusClassOf(id) {
  if (!isBuiltin(id) || !META[id]) return ""
  var klass = META[id].focusClass
  return typeof klass === "string" ? klass : ""
}

function classMatchesDesktop(klass, initialClass, desktopId) {
  var id = String(desktopId || "").toLowerCase()
  if (!id) return false
  var klassL = String(klass || "").toLowerCase()
  var initial = String(initialClass || "").toLowerCase()
  var lastDot = id.lastIndexOf(".")
  var last = lastDot >= 0 ? id.substring(lastDot + 1) : id
  if (klassL === id || initial === id) return true
  if (klassL === last || initial === last) return true
  if (klassL.replace(/_/g, "-") === id || initial.replace(/_/g, "-") === id) return true
  return false
}

function isWindowAddress(addr) {
  return typeof addr === "string" && /^0x[0-9a-fA-F]{4,18}$/.test(addr)
}

function findClient(rawJson, desktopId, workspaceKey) {
  var desk = normalizeDesktopId(desktopId)
  if (!desk) return null
  var list
  try { list = JSON.parse(String(rawJson || "")) } catch (e) { return null }
  if (!Array.isArray(list)) return null
  var n = list.length
  if (typeof n !== "number" || n < 0) return null
  if (n > 256) n = 256
  var fallback = null
  var wantWs = workspaceKey ? String(workspaceKey) : ""
  for (var i = 0; i < n; i++) {
    var client = list[i]
    if (!client || typeof client !== "object") continue
    if (client.mapped === false) continue
    if (!classMatchesDesktop(client["class"], client.initialClass, desk)) continue
    var addr = String(client.address || "")
    if (!isWindowAddress(addr)) continue
    var ws = client.workspace && client.workspace.id != null ? String(client.workspace.id) : ""
    var hit = { address: addr, workspace: isWorkspaceKey(ws) ? ws : "" }
    if (wantWs && ws === wantWs) return hit
    if (!fallback) fallback = hit
  }
  return fallback
}

function findClientAddress(rawJson, desktopId, workspaceKey) {
  var hit = findClient(rawJson, desktopId, workspaceKey)
  return hit ? hit.address : ""
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
