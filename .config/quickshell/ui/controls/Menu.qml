import QtQuick
import "../primitives" as Ui
import "../../theme"

Ui.UiSurface {
  id: root

  default property alias content: listColumn.data

  width: parent ? parent.width : implicitWidth
  implicitWidth: 1
  implicitHeight: listColumn.implicitHeight + 12
  tone: "panelOverlay"
  outlined: false
  radius: 16

  border.width: 1
  border.color: Theme.border

  Column {
    id: listColumn

    width: parent.width - 20
    anchors.left: parent.left
    anchors.leftMargin: 10
    anchors.top: parent.top
    anchors.topMargin: 6
    spacing: 1
  }
}
