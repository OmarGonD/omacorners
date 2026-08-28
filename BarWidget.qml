import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.omargond.omacorners"

  readonly property var svc: bar && bar.shell && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor(moduleName) : null

  function assigned(which) {
    if (!svc || typeof svc.resolvedCorner !== "function") return false
    return svc.resolvedCorner(which) !== "none"
  }

  function tooltip() {
    if (!svc || typeof svc.prettyLabel !== "function") return "Omacorners"
    return "Omacorners  ws " + String(svc.workspaceKey || "–")
      + "\nTL " + svc.prettyLabel(svc.resolvedCorner("topLeft"))
      + " · TR " + svc.prettyLabel(svc.resolvedCorner("topRight"))
      + "\nBL " + svc.prettyLabel(svc.resolvedCorner("bottomLeft"))
      + " · BR " + svc.prettyLabel(svc.resolvedCorner("bottomRight"))
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    keepSpace: true
    hasVisualContent: true
    labelVisible: false
    tooltipText: root.tooltip()
    fixedWidth: root.vertical ? root.barSize : Style.space(22)
    fixedHeight: root.vertical ? Style.space(22) : root.barSize
    onPressed: function() {
      if (root.bar && root.bar.shell && typeof root.bar.shell.toggle === "function")
        root.bar.shell.toggle(root.moduleName)
    }

    Grid {
      anchors.centerIn: parent
      columns: 2
      rows: 2
      spacing: Math.max(2, Style.space(2))

      Repeater {
        model: ["topLeft", "topRight", "bottomLeft", "bottomRight"]
        Rectangle {
          required property string modelData
          width: Math.max(4, Style.space(5))
          height: width
          radius: width / 2
          color: root.assigned(modelData)
            ? button.foreground
            : Util.alpha(button.foreground, 0.28)
        }
      }
    }
  }
}
