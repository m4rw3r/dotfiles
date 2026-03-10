import QtQuick
import "../../theme"

Item {
  id: root

  property string iconName: "wifi"
  property string title: ""
  property bool active: false
  signal clicked()

  implicitWidth: parent ? Math.floor((parent.width - Theme.gapSm) / 2) : Theme.popoverWidthSm
  implicitHeight: Theme.tileHeight
  opacity: enabled ? 1 : 0.5

  readonly property bool pressed: touchArea.pressed

  QuickTileFrame {
    anchors.fill: parent
    iconName: root.iconName
    title: root.title
    backgroundColor: root.active
      ? (root.pressed ? Theme.toggleOnStrong : Theme.toggleOn)
      : (root.pressed ? Theme.fieldPressed : Theme.field)
    borderColor: root.active ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08)
    iconColor: root.active ? Theme.textOnAccent : Theme.text
    textTone: root.active ? "onAccent" : "primary"
  }

  MouseArea {
    id: touchArea

    anchors.fill: parent
    enabled: root.enabled
    onClicked: root.clicked()
  }
}
