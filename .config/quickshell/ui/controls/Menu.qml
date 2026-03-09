import QtQuick
import "../primitives" as Ui
import "../../theme"

Ui.UiSurface {
  id: root

  default property alias content: listColumn.data

  width: parent ? parent.width : implicitWidth
  implicitWidth: 1
  implicitHeight: listColumn.implicitHeight + Theme.gapMd
  tone: "panelOverlay"
  outlined: false
  radius: Theme.radiusMd

  border.width: Theme.stroke
  border.color: Qt.rgba(1, 1, 1, 0.08)

  Column {
    id: listColumn

    width: parent.width - Theme.insetLg
    anchors.left: parent.left
    anchors.leftMargin: Theme.insetSm
    anchors.top: parent.top
    anchors.topMargin: Theme.gapXs
    spacing: Theme.nudge
  }
}
