import QtQuick
import "../primitives" as Ui
import "../../theme"

Ui.UiSurface {
  id: root

  property string iconName: ""
  property string title: ""
  property string subtitle: ""
  property int horizontalPadding: 20
  property int verticalPadding: 20
  property int sectionSpacing: 18
  default property alias content: bodyColumn.data

  width: implicitWidth
  implicitWidth: 1
  implicitHeight: sheetColumn.implicitHeight + verticalPadding * 2
  tone: "submenu"
  outlined: false
  radius: 28
  color: Theme.submenu
  z: 8
  clip: true

  border.width: 1
  border.color: Qt.rgba(1, 1, 1, 0.08)

  Column {
    id: sheetColumn

    width: parent.width - root.horizontalPadding * 2
    anchors.left: parent.left
    anchors.leftMargin: root.horizontalPadding
    anchors.top: parent.top
    anchors.topMargin: root.verticalPadding
    spacing: root.sectionSpacing

    Row {
      width: parent.width
      spacing: 14

      Rectangle {
        width: 56
        height: 56
        radius: 28
        color: Qt.rgba(1, 1, 1, 0.16)

        Ui.UiIcon {
          anchors.centerIn: parent
          width: 26
          height: 26
          name: root.iconName
          strokeColor: Theme.text
          stroke: 2.1
        }
      }

      Column {
        width: Math.max(0, parent.width - 70)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Ui.UiText {
          width: parent.width
          text: root.title
          size: "xl"
          font.weight: Font.Bold
          elide: Text.ElideRight
        }

        Ui.UiText {
          width: parent.width
          visible: text !== ""
          text: root.subtitle
          size: "xs"
          tone: "subtle"
          wrapMode: Text.WordWrap
        }
      }
    }

    Column {
      id: bodyColumn

      width: parent.width
      spacing: 0
    }
  }
}
