import QtQuick
import "../primitives" as Ui

Ui.UiSurface {
  id: root

  default property alias content: listColumn.data

  width: parent ? parent.width : implicitWidth
  implicitWidth: 1
  implicitHeight: listColumn.implicitHeight + 16
  tone: "panelOverlay"
  outlined: false
  radius: 20

  border.width: 1
  border.color: Qt.rgba(1, 1, 1, 0.08)

  Column {
    id: listColumn

    width: parent.width - 24
    anchors.left: parent.left
    anchors.leftMargin: 12
    anchors.top: parent.top
    anchors.topMargin: 8
    spacing: 2
  }
}
