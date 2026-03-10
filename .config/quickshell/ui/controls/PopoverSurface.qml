import QtQuick
import "../primitives" as Ui
import "../../theme"

Ui.UiSurface {
  id: root

  default property alias content: popoverColumn.data
  property int horizontalPadding: Theme.insetSm
  property int verticalPadding: Theme.insetSm

  width: implicitWidth
  height: implicitHeight
  implicitWidth: Theme.popoverWidthSm
  implicitHeight: popoverColumn.implicitHeight + verticalPadding * 2
  tone: "submenu"
  outlined: false
  radius: Theme.radiusMd
  z: 8
  clip: true

  border.width: Theme.stroke
  border.color: Qt.rgba(1, 1, 1, 0.08)

  Column {
    id: popoverColumn

    width: parent.width - root.horizontalPadding * 2
    x: root.horizontalPadding
    y: root.verticalPadding
    spacing: Theme.nudge
  }
}
