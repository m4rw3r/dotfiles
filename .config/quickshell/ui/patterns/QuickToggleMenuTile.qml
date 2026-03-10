import QtQuick
import "../primitives" as Ui
import "../../theme"

Item {
  id: root

  property string iconName: "wifi"
  property string title: ""
  property bool active: false
  property bool menuOpen: false
  signal primaryClicked()
  signal secondaryClicked()

  implicitWidth: parent ? Math.floor((parent.width - Theme.gapSm) / 2) : Theme.popoverWidthSm
  implicitHeight: Theme.tileHeight
  opacity: enabled ? 1 : 0.5

  readonly property real splitWidth: Theme.tileSplitWidth
  readonly property real splitInset: Theme.stroke
  readonly property bool primaryPressed: primaryTouch.pressed
  readonly property bool secondaryPressed: secondaryTouch.pressed

  QuickTileFrame {
    anchors.fill: parent
    iconName: root.iconName
    title: root.title
    backgroundColor: root.active
      ? (root.primaryPressed ? Theme.toggleOnStrong : Theme.toggleOn)
      : (root.primaryPressed ? Theme.fieldPressed : Theme.field)
    borderColor: root.active
      ? Qt.rgba(1, 1, 1, 0.12)
      : (root.menuOpen ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08))
    iconColor: root.active ? Theme.textOnAccent : Theme.text
    textTone: root.active ? "onAccent" : "primary"
    split: true
    trailingWidth: root.splitWidth
    splitWidth: root.splitWidth
    splitInset: root.splitInset
    splitColor: root.active
      ? (root.secondaryPressed ? Theme.toggleOnStrong : Qt.lighter(backgroundColor, 1.05))
      : ((root.secondaryPressed || root.menuOpen) ? Theme.fieldAlt : Qt.lighter(backgroundColor, 1.03))
    separatorColor: root.active ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)

    Ui.UiIcon {
      anchors.centerIn: parent
      width: Theme.iconGlyphSm
      height: Theme.iconGlyphSm
      name: root.menuOpen ? "chevron-down" : "chevron-right"
      strokeColor: root.active ? Theme.textOnAccent : Theme.text
    }
  }

  MouseArea {
    id: primaryTouch

    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    anchors.rightMargin: root.splitWidth
    enabled: root.enabled
    onClicked: root.primaryClicked()
  }

  MouseArea {
    id: secondaryTouch

    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    width: root.splitWidth
    enabled: root.enabled
    onClicked: root.secondaryClicked()
  }
}
