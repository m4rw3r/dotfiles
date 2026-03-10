import QtQuick
import "../controls" as Controls
import "../primitives" as Ui
import "../../theme"

Controls.PopoverSurface {
  id: root

  property string iconName: "wifi"
  property string title: ""
  property int horizontalPadding: Theme.insetMd
  property int verticalPadding: Theme.insetMd
  default property alias content: bodyColumn.data

  width: implicitWidth
  implicitWidth: Theme.popoverWidthMd
  implicitHeight: contentColumn.implicitHeight + verticalPadding * 2
  radius: Theme.radiusLg

  Column {
    id: contentColumn

    width: parent.width
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
