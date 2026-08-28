import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Actions.js" as Actions
import "Corners.js" as Corners

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var service: null

  property bool opened: false
  property bool editLocal: false
  property int delayPreview: -1
  property int thresholdPreview: -1
  property int powerPreview: -1

  readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "io.github.omargond.omacorners"
  readonly property var svc: service
  readonly property bool ready: svc !== null && svc !== undefined

  readonly property color background: Color.menu.background
  readonly property color foreground: Color.menu.text
  readonly property color border: Color.menu.border
  readonly property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  readonly property color scrim: Color.menu.scrim
  readonly property color accent: Color.accent
  readonly property int cornerRadius: Style.cornerRadius
  readonly property string fontFamily: Style.font.menuFamily
  readonly property int contentMargin: Style.spacing.panelPadding
  readonly property int cardWidth: Math.min(Style.space(580), panel.width - Style.gapsOut * 2)
  readonly property int cardHeight: Math.min(Style.space(760), panel.height - Style.gapsOut * 2)
  readonly property string scopeKey: ready ? String(svc.workspaceKey || "") : ""
  readonly property bool canEditLocal: scopeKey !== ""
  readonly property bool editingLocal: editLocal && canEditLocal

  readonly property int shownDelay: delayPreview >= 0 ? delayPreview : (ready ? svc.delayMs : 400)
  readonly property int shownThreshold: thresholdPreview >= 0 ? thresholdPreview : (ready ? svc.thresholdPx : 8)
  readonly property int shownPowerDelay: powerPreview >= 0 ? powerPreview : (ready ? svc.powerDelayMs : 800)
  readonly property var actionOptions: ready && svc.actionOptions ? svc.actionOptions : Actions.options()

  function open(payloadJson) {
    opened = true
    delayPreview = -1
    thresholdPreview = -1
    powerPreview = -1
    if (ready && typeof svc.refreshActionOptions === "function") svc.refreshActionOptions()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    opened = false
    delayPreview = -1
    thresholdPreview = -1
    powerPreview = -1
  }

  function dismiss() {
    opened = false
    if (shell && typeof shell.hide === "function")
      shell.hide(pluginId)
  }

  function toggle() {
    if (opened) dismiss()
    else open("{}")
  }

  function cornerValue(which) {
    if (!ready) return "none"
    if (editingLocal && typeof svc.resolvedCorner === "function") return svc.resolvedCorner(which)
    return Actions.normalize(svc[which])
  }

  function setCorner(which, value) {
    if (!ready || typeof svc.setCorner !== "function") return
    if (editingLocal) svc.setCorner(which, value, scopeKey)
    else svc.setCorner(which, value)
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omacorners-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (topLeftPick.popupOpen || topRightPick.popupOpen
              || bottomLeftPick.popupOpen || bottomRightPick.popupOpen) {
            return
          }
          if (event.key === Qt.Key_Escape) {
            root.dismiss()
            event.accepted = true
          }
        }
      }

      Flickable {
        id: scroller
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        clip: true
        contentWidth: width
        contentHeight: inner.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

      ColumnLayout {
        id: inner
        width: scroller.width
        spacing: Style.space(12)

        Column {
          Layout.fillWidth: true
          spacing: Style.space(4)

          Text {
            text: "Omacorners"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            font.bold: true
          }

          Text {
            width: parent.width
            text: editingLocal
              ? ("Overrides for workspace " + scopeKey + " inherit everything you leave unchanged.")
              : "Defaults for every workspace. Hold Super if that toggle is on."
            color: root.foreground
            opacity: 0.7
            wrapMode: Text.WordWrap
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        Toggle {
          Layout.fillWidth: true
          label: "Enabled"
          description: "Pause hot corners without losing your assignments"
          checked: root.ready ? svc.active : true
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: if (root.ready) svc.setActive(!(svc.active === true))
        }

        Toggle {
          Layout.fillWidth: true
          label: "This workspace only"
          description: canEditLocal
            ? ("Edit workspace " + scopeKey + ". Reset clears just these overrides.")
            : "Switch to a numbered workspace to add overrides"
          checked: root.editingLocal
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: {
            if (!root.canEditLocal) return
            root.editLocal = !root.editLocal
          }
        }

        Button {
          Layout.fillWidth: true
          visible: root.editingLocal && root.ready && Actions.hasOverride(root.svc.workspaceMap, root.scopeKey)
          text: "Reset this workspace"
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: if (root.ready) root.svc.clearWorkspace(root.scopeKey)
        }

        Toggle {
          Layout.fillWidth: true
          label: "Hold Super to arm"
          description: "Corners only fire while Super is held. Prevents edge-drag accidents."
          checked: root.ready ? svc.requireSuper !== false : true
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: if (root.ready) svc.setRequireSuper(!(svc.requireSuper !== false))
        }

        Toggle {
          Layout.fillWidth: true
          label: "Ignore fullscreen"
          description: "Do not fire while the active window is fullscreen"
          checked: root.ready ? svc.suppressFullscreen !== false : true
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: if (root.ready) svc.setSuppressFullscreen(!(svc.suppressFullscreen !== false))
        }

        Toggle {
          Layout.fillWidth: true
          label: "Ignore while dragging"
          description: "Do not fire while a pointer button is held"
          checked: root.ready ? svc.suppressDrag !== false : true
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: if (root.ready) svc.setSuppressDrag(!(svc.suppressDrag !== false))
        }

        Toggle {
          Layout.fillWidth: true
          label: "Ignore menus and pickers"
          description: "Do not fire over the Omarchy menu, emojis, or clipboard"
          checked: root.ready ? svc.suppressOverlay !== false : true
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: if (root.ready) svc.setSuppressOverlay(!(svc.suppressOverlay !== false))
        }

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(188)

          Rectangle {
            id: monitor
            anchors.centerIn: parent
            width: Math.min(parent.width - Style.space(24), Style.space(360))
            height: Math.round(width * 9 / 16)
            radius: Math.max(4, root.cornerRadius)
            color: Util.alpha(root.foreground, 0.06)
            border.color: Util.alpha(root.foreground, 0.18)
            border.width: Math.max(1, Style.space(2))

            Repeater {
              model: [
                { id: "tl", x: 0, y: 0 },
                { id: "tr", x: 1, y: 0 },
                { id: "bl", x: 0, y: 1 },
                { id: "br", x: 1, y: 1 }
              ]
              Rectangle {
                required property var modelData
                readonly property string cornerId: modelData.id
                readonly property string which: cornerId === "tl" ? "topLeft"
                  : cornerId === "tr" ? "topRight"
                  : cornerId === "bl" ? "bottomLeft" : "bottomRight"
                readonly property bool assigned: root.cornerValue(which) !== "none"
                readonly property bool live: root.ready && svc.liveCorner === cornerId
                width: Style.space(18)
                height: Style.space(18)
                radius: width / 2
                x: modelData.x === 0 ? -width / 2 : monitor.width - width / 2
                y: modelData.y === 0 ? -height / 2 : monitor.height - height / 2
                color: live ? root.accent : (assigned ? Util.alpha(root.accent, 0.85) : Util.alpha(root.foreground, 0.35))
                scale: live ? 1.25 : 1
                Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
              }
            }

            Text {
              anchors.centerIn: parent
              text: root.ready && svc.liveCorner !== ""
                ? root.svc.labelForCorner(root.svc.liveCorner)
                : "screen"
              color: root.foreground
              opacity: 0.45
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        GridLayout {
          Layout.fillWidth: true
          columns: 2
          columnSpacing: Style.space(12)
          rowSpacing: Style.space(10)

          SearchableDropdown {
            id: topLeftPick
            Layout.fillWidth: true
            label: "Top left"
            value: root.cornerValue("topLeft")
            options: root.actionOptions
            placeholderText: "Search actions or apps…"
            emptyText: "No matches"
            foreground: root.foreground
            background: root.background
            fontFamily: root.fontFamily
            onChanged: function(v) { root.setCorner("topLeft", v) }
          }

          SearchableDropdown {
            id: topRightPick
            Layout.fillWidth: true
            label: "Top right"
            value: root.cornerValue("topRight")
            options: root.actionOptions
            placeholderText: "Search actions or apps…"
            emptyText: "No matches"
            foreground: root.foreground
            background: root.background
            fontFamily: root.fontFamily
            onChanged: function(v) { root.setCorner("topRight", v) }
          }

          SearchableDropdown {
            id: bottomLeftPick
            Layout.fillWidth: true
            label: "Bottom left"
            value: root.cornerValue("bottomLeft")
            options: root.actionOptions
            placeholderText: "Search actions or apps…"
            emptyText: "No matches"
            foreground: root.foreground
            background: root.background
            fontFamily: root.fontFamily
            onChanged: function(v) { root.setCorner("bottomLeft", v) }
          }

          SearchableDropdown {
            id: bottomRightPick
            Layout.fillWidth: true
            label: "Bottom right"
            value: root.cornerValue("bottomRight")
            options: root.actionOptions
            placeholderText: "Search actions or apps…"
            emptyText: "No matches"
            foreground: root.foreground
            background: root.background
            fontFamily: root.fontFamily
            onChanged: function(v) { root.setCorner("bottomRight", v) }
          }
        }

        Column {
          Layout.fillWidth: true
          spacing: Style.space(6)

          Row {
            width: parent.width
            Text {
              text: "Delay"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
            Item { width: Style.space(8); height: 1 }
            Text {
              text: (root.shownDelay / 1000).toFixed(2) + " s"
              color: root.foreground
              opacity: 0.7
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          PanelSlider {
            width: parent.width
            value: root.shownDelay
            minimum: 0
            maximum: 2000
            step: 50
            integer: true
            fillColor: root.foreground
            knobColor: root.foreground
            trackColor: Util.alpha(root.foreground, 0.18)
            tickColor: root.background
            onMoved: function(v) { root.delayPreview = Corners.clampDelayMs(v) }
            onReleased: function(v) {
              root.delayPreview = -1
              if (root.ready) root.svc.setDelayMs(v)
            }
          }
        }

        Column {
          Layout.fillWidth: true
          spacing: Style.space(6)

          Row {
            width: parent.width
            Text {
              text: "Corner size"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
            Item { width: Style.space(8); height: 1 }
            Text {
              text: root.shownThreshold + " px"
              color: root.foreground
              opacity: 0.7
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          PanelSlider {
            width: parent.width
            value: root.shownThreshold
            minimum: 2
            maximum: 48
            step: 1
            integer: true
            fillColor: root.foreground
            knobColor: root.foreground
            trackColor: Util.alpha(root.foreground, 0.18)
            tickColor: root.background
            onMoved: function(v) { root.thresholdPreview = Corners.clampThresholdPx(v) }
            onReleased: function(v) {
              root.thresholdPreview = -1
              if (root.ready) root.svc.setThresholdPx(v)
            }
          }
        }

        Column {
          Layout.fillWidth: true
          spacing: Style.space(6)

          Row {
            width: parent.width
            Text {
              text: "Extra delay for shut down / restart"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
            Item { width: Style.space(8); height: 1 }
            Text {
              text: "+" + (root.shownPowerDelay / 1000).toFixed(2) + " s"
              color: root.foreground
              opacity: 0.7
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          PanelSlider {
            width: parent.width
            value: root.shownPowerDelay
            minimum: 0
            maximum: 2000
            step: 50
            integer: true
            fillColor: root.foreground
            knobColor: root.foreground
            trackColor: Util.alpha(root.foreground, 0.18)
            tickColor: root.background
            onMoved: function(v) { root.powerPreview = Actions.clampPowerDelayMs(v) }
            onReleased: function(v) {
              root.powerPreview = -1
              if (root.ready) root.svc.setPowerDelayMs(v)
            }
          }
        }

        Text {
          Layout.fillWidth: true
          text: "Esc closes this panel. Super+Space, then search Omacorners."
          color: root.foreground
          opacity: 0.45
          wrapMode: Text.WordWrap
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
      }
    }
  }
}
