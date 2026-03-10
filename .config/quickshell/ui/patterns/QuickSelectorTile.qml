import QtQuick
import "../../theme"

Item {
  id: root

  property string iconName: "gauge"
  property string title: ""
  property bool active: false
  property bool useActiveStyling: true
  property bool open: false
  signal clicked()

  implicitWidth: parent ? Math.floor((parent.width - Theme.gapSm) / 2) : Theme.popoverWidthSm
  implicitHeight: Theme.tileHeight
  opacity: enabled ? 1 : 0.5

  readonly property bool pressed: touchArea.pressed
  readonly property bool highlighted: useActiveStyling && active

  QuickTileFrame {
    anchors.fill: parent
    iconName: root.iconName
    title: root.title
    backgroundColor: root.highlighted
      ? (root.pressed ? Theme.toggleOnStrong : Theme.toggleOn)
      : ((root.pressed || root.open) ? Theme.fieldAlt : Theme.field)
    borderColor: root.highlighted
      ? Qt.rgba(1, 1, 1, 0.12)
      : (root.open ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08))
    iconColor: root.highlighted ? Theme.textOnAccent : Theme.text
    textTone: root.highlighted ? "onAccent" : "primary"
  }

  MouseArea {
    id: touchArea

    anchors.fill: parent
    enabled: root.enabled
    onClicked: root.clicked()
  }
}
