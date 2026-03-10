import QtQuick
import "../primitives" as Ui
import "../../theme"

Ui.UiSurface {
  id: root

  property string text: ""
  property string iconName: ""

  implicitWidth: chipRow.implicitWidth + Theme.gapLg
  implicitHeight: Theme.controlSm
  tone: "field"
  outlined: false
  radius: Theme.radiusMd

  border.width: Theme.stroke
  border.color: Qt.rgba(1, 1, 1, 0.08)

  Row {
    id: chipRow

    anchors.centerIn: parent
    spacing: root.iconName === "" ? 0 : Theme.gapXs

    Ui.UiIcon {
      visible: root.iconName !== ""
      anchors.verticalCenter: parent.verticalCenter
      name: root.iconName
      strokeColor: Theme.text
    }

    Ui.UiText {
      anchors.verticalCenter: parent.verticalCenter
      text: root.text
      size: "sm"
      tone: "primary"
      font.weight: Font.DemiBold
    }
  }
}
