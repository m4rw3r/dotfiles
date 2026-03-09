import QtQuick
import "../primitives" as Ui
import "../../theme"

Ui.UiSurface {
  id: root

  property string iconName: "wifi"
  property string title: ""
  property int horizontalPadding: Theme.insetMd
  property int verticalPadding: Theme.insetMd
  default property alias content: bodyColumn.data

  width: implicitWidth
  implicitWidth: Theme.popoverWidthMd
  implicitHeight: headerRow.implicitHeight + bodyColumn.implicitHeight + verticalPadding * 2 + Theme.gapSm
  tone: "submenu"
  outlined: false
  radius: Theme.radiusLg
  z: 8
  clip: true

  border.width: Theme.stroke
  border.color: Qt.rgba(1, 1, 1, 0.08)

  Column {
    width: parent.width - root.horizontalPadding * 2
    anchors.left: parent.left
    anchors.leftMargin: root.horizontalPadding
    anchors.top: parent.top
    anchors.topMargin: root.verticalPadding
    spacing: Theme.gapSm

    Row {
      id: headerRow

      width: parent.width
      spacing: Theme.gapXs

      Rectangle {
        width: Theme.controlSm
        height: Theme.controlSm
        radius: Theme.controlSm / 2
        color: Theme.field

        Ui.UiIcon {
          anchors.centerIn: parent
          name: root.iconName
          strokeColor: Theme.text
        }
      }

      Ui.UiText {
        width: Math.max(0, parent.width - Theme.controlSm - Theme.gapSm)
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
      spacing: Theme.gapXs
    }
  }
}
