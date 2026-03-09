import QtQuick
import "../primitives" as Ui
import "../../theme"

Ui.UiSurface {
  id: root

  property string iconName: "wifi"
  property string title: ""
  property int horizontalPadding: 14
  property int verticalPadding: 14
  default property alias content: bodyColumn.data

  width: implicitWidth
  implicitWidth: 228
  implicitHeight: headerRow.implicitHeight + bodyColumn.implicitHeight + verticalPadding * 2 + 12
  tone: "submenu"
  outlined: false
  radius: 24
  z: 8
  clip: true

  border.width: 1
  border.color: Qt.rgba(1, 1, 1, 0.08)

  Column {
    width: parent.width - root.horizontalPadding * 2
    anchors.left: parent.left
    anchors.leftMargin: root.horizontalPadding
    anchors.top: parent.top
    anchors.topMargin: root.verticalPadding
    spacing: 12

    Row {
      id: headerRow

      width: parent.width
      spacing: 10

      Rectangle {
        width: 36
        height: 36
        radius: 18
        color: Theme.field

        Ui.UiIcon {
          anchors.centerIn: parent
          name: root.iconName
          strokeColor: Theme.text
        }
      }

      Ui.UiText {
        width: Math.max(0, parent.width - 46)
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        size: "md"
        font.weight: Font.DemiBold
        elide: Text.ElideRight
      }
    }

    Column {
      id: bodyColumn

      width: parent.width
      spacing: 8
    }
  }
}
