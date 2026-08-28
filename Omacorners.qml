import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "Corners.js" as Corners
import "Actions.js" as Actions

Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "io.github.omargond.omacorners"
  readonly property string pluginDir: {
    var url = Qt.resolvedUrl(".")
    return url.toString().replace(/^file:\/\//, "").replace(/\/$/, "")
  }
  readonly property string helperPath: pluginDir + "/scripts/omacorners-cursor"

  readonly property var pluginEntry: {
    var cfg = shell ? shell.shellConfig : null
    var list = cfg && Array.isArray(cfg.plugins) ? cfg.plugins : []
    for (var i = 0; i < list.length; i++) {
      if (list[i] && String(list[i].id || "") === pluginId) return list[i]
    }
    return ({})
  }

  readonly property bool active: pluginEntry.active === false ? false : true
  readonly property int delayMs: Corners.clampDelayMs(pluginEntry.delayMs === undefined ? 400 : pluginEntry.delayMs)
  readonly property int thresholdPx: Corners.clampThresholdPx(pluginEntry.thresholdPx === undefined ? 8 : pluginEntry.thresholdPx)
  readonly property string topLeft: Actions.normalize(pluginEntry.topLeft)
  readonly property string topRight: Actions.normalize(pluginEntry.topRight)
  readonly property string bottomLeft: Actions.normalize(pluginEntry.bottomLeft)
  readonly property string bottomRight: Actions.normalize(pluginEntry.bottomRight)
  readonly property bool welcomed: pluginEntry.welcomed === true

  property var actionOptions: []

  property int cursorX: -100000
  property int cursorY: -100000
  property string dwellCorner: ""
  property string dwellScreen: ""
  property real dwellProgress: 0
  property double dwellStartedAt: 0
  property bool latched: false
  property bool pulsing: false
  property int helperRestarts: 0
  property bool helperStarted: false

  readonly property string liveCorner: dwellCorner
  readonly property string liveScreen: dwellScreen
  readonly property real liveProgress: dwellProgress

  function actionForCorner(corner) {
    if (corner === "tl") return topLeft
    if (corner === "tr") return topRight
    if (corner === "bl") return bottomLeft
    if (corner === "br") return bottomRight
    return "none"
  }

  function labelForCorner(corner) {
    return Actions.labelOf(actionForCorner(corner))
  }

  function persist(changes) {
    var entry = {
      id: pluginId,
      active: active,
      delayMs: delayMs,
      thresholdPx: thresholdPx,
      topLeft: topLeft,
      topRight: topRight,
      bottomLeft: bottomLeft,
      bottomRight: bottomRight,
      welcomed: welcomed
    }
    if (changes) {
      for (var key in changes) entry[key] = changes[key]
    }
    if (entry.topLeft !== undefined) entry.topLeft = Actions.normalize(entry.topLeft)
    if (entry.topRight !== undefined) entry.topRight = Actions.normalize(entry.topRight)
    if (entry.bottomLeft !== undefined) entry.bottomLeft = Actions.normalize(entry.bottomLeft)
    if (entry.bottomRight !== undefined) entry.bottomRight = Actions.normalize(entry.bottomRight)
    if (entry.delayMs !== undefined) entry.delayMs = Corners.clampDelayMs(entry.delayMs)
    if (entry.thresholdPx !== undefined) entry.thresholdPx = Corners.clampThresholdPx(entry.thresholdPx)
    if (shell && typeof shell.updateEntryInline === "function")
      shell.updateEntryInline(pluginId, entry)
  }

  function setCorner(which, id) {
    if (which !== "topLeft" && which !== "topRight" && which !== "bottomLeft" && which !== "bottomRight")
      return
    var changes = {}
    changes[which] = Actions.normalize(id)
    persist(changes)
  }

  function setDelayMs(value) {
    persist({ delayMs: Corners.clampDelayMs(value) })
  }

  function setThresholdPx(value) {
    persist({ thresholdPx: Corners.clampThresholdPx(value) })
  }

  function setActive(value) {
    persist({ active: value !== false })
  }

  onActiveChanged: {
    if (active) startHelper()
    else {
      stopHelper()
      clearDwell()
    }
  }

  function clearDwell() {
    dwellTimer.stop()
    dwellCorner = ""
    dwellScreen = ""
    dwellProgress = 0
  }

  function onCursor(x, y) {
    cursorX = x
    cursorY = y
    if (!active) {
      clearDwell()
      return
    }
    var hit = Corners.hit(Corners.screensFromModel(Quickshell.screens), x, y, thresholdPx)
    if (!hit || actionForCorner(hit.corner) === "none") {
      latched = false
      clearDwell()
      return
    }
    if (latched && hit.corner === dwellCorner && hit.name === dwellScreen) return
    if (hit.corner === dwellCorner && hit.name === dwellScreen) {
      updateProgress()
      return
    }
    latched = false
    dwellCorner = hit.corner
    dwellScreen = hit.name
    dwellStartedAt = Date.now()
    dwellProgress = delayMs <= 0 ? 1 : 0
    if (delayMs <= 0) fire()
    else dwellTimer.restart()
  }

  function updateProgress() {
    if (delayMs <= 0) {
      dwellProgress = 1
      return
    }
    dwellProgress = Math.max(0, Math.min(1, (Date.now() - dwellStartedAt) / delayMs))
  }

  function fire() {
    if (!active || latched || dwellCorner === "") return
    var action = actionForCorner(dwellCorner)
    if (action === "none") return
    latched = true
    dwellProgress = 1
    pulsing = true
    pulseTimer.restart()
    Actions.run(action, function(dispatch) {
      Hyprland.dispatch(dispatch)
    }, function(argv) {
      Util.execArgv(argv)
    })
  }

  function startHelper() {
    if (!active) return
    if (helperProc.running) return
    helperProc.running = true
    helperStarted = true
  }

  function stopHelper() {
    if (helperProc.running) helperProc.running = false
    helperStarted = false
  }

  Component.onCompleted: {
    actionOptions = Actions.options()
    if (active) startHelper()
    if (!welcomed) welcomeTimer.start()
  }

  onWelcomedChanged: if (welcomed) welcomeTimer.stop()

  Component.onDestruction: stopHelper()

  Timer {
    id: welcomeTimer
    interval: 1500
    repeat: false
    onTriggered: {
      if (root.welcomed) return
      root.persist({ welcomed: true })
      Quickshell.execDetached([
        "omarchy-notification-send",
        "Omacorners is on",
        "Open settings to assign an action to each screen corner."
      ])
    }
  }

  Timer {
    id: dwellTimer
    interval: Math.max(1, root.delayMs)
    repeat: false
    onTriggered: root.fire()
  }

  Timer {
    id: progressTimer
    interval: 16
    repeat: true
    running: root.dwellCorner !== "" && !root.latched && root.delayMs > 0
    onTriggered: root.updateProgress()
  }

  Timer {
    id: pulseTimer
    interval: 280
    repeat: false
    onTriggered: root.pulsing = false
  }

  Timer {
    id: helperRestartTimer
    interval: Math.min(8000, 500 * Math.pow(2, Math.min(4, root.helperRestarts)))
    repeat: false
    onTriggered: {
      if (root.active) root.startHelper()
    }
  }

  Process {
    id: helperProc
    running: false
    command: ["python3", root.helperPath]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) {
        var line = String(data || "").trim()
        if (line.indexOf("POS ") !== 0) return
        var parts = line.split(" ")
        if (parts.length !== 3) return
        var x = parseInt(parts[1], 10)
        var y = parseInt(parts[2], 10)
        if (isNaN(x) || isNaN(y)) return
        root.helperRestarts = 0
        root.onCursor(x, y)
      }
    }

    stderr: SplitParser {
      splitMarker: "\n"
      onRead: function(data) {
        var line = String(data || "").trim()
        if (line) console.warn("omacorners-cursor: " + line)
      }
    }

    onExited: function(code) {
      root.helperStarted = false
      if (!root.active) return
      root.helperRestarts += 1
      if (root.helperRestarts > 12) {
        console.warn("omacorners: helper gave up after repeated exits, code " + code)
        return
      }
      helperRestartTimer.restart()
    }
  }

  IpcHandler {
    target: "omacorners"
    function ping(): string { return "ok" }
    function status(): string {
      return JSON.stringify({
        active: root.active,
        delayMs: root.delayMs,
        thresholdPx: root.thresholdPx,
        topLeft: root.topLeft,
        topRight: root.topRight,
        bottomLeft: root.bottomLeft,
        bottomRight: root.bottomRight,
        cursorX: root.cursorX,
        cursorY: root.cursorY,
        dwellCorner: root.dwellCorner,
        helper: helperProc.running
      })
    }
    function toggle(): string {
      if (root.shell && typeof root.shell.toggle === "function") {
        root.shell.toggle(root.pluginId)
        return "ok"
      }
      return "no-shell"
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: glowWindow
      required property var modelData
      screen: modelData
      visible: true
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "omacorners-glow"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      anchors { top: true; bottom: true; left: true; right: true }
      mask: Region {}

      readonly property bool onThisScreen: root.dwellScreen === String(modelData.name || "")
      readonly property bool showGlow: root.active && onThisScreen && root.dwellCorner !== ""
      readonly property real glowSize: Style.space(root.pulsing ? 168 : (110 + Math.round(50 * root.dwellProgress)))
      readonly property real glowOpacity: {
        if (!showGlow) return 0
        if (root.pulsing) return 0.55
        return 0.12 + 0.38 * root.dwellProgress
      }

      function glowX(corner) {
        if (corner === "tr" || corner === "br") return glowWindow.width - glowSize / 2
        return -glowSize / 2
      }

      function glowY(corner) {
        if (corner === "bl" || corner === "br") return glowWindow.height - glowSize / 2
        return -glowSize / 2
      }

      Rectangle {
        id: glow
        width: glowWindow.glowSize
        height: glowWindow.glowSize
        radius: width / 2
        x: glowWindow.glowX(root.dwellCorner)
        y: glowWindow.glowY(root.dwellCorner)
        color: Color.accent
        opacity: glowWindow.glowOpacity
        visible: glowWindow.showGlow && opacity > 0.01

        Behavior on opacity { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
      }
    }
  }
}
