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

  implicitWidth: parent ? Math.floor((parent.width - 10) / 2) : 180
  implicitHeight: 44
  opacity: enabled ? 1 : 0.5

  readonly property real tileRadius: 18
  readonly property real splitWidth: 36
  readonly property real splitInset: 1
  readonly property bool primaryPressed: primaryTouch.pressed
  readonly property bool secondaryPressed: secondaryTouch.pressed
  readonly property color tileColor: active
    ? (primaryPressed ? Theme.toggleOnStrong : Theme.toggleOn)
    : (primaryPressed ? Theme.fieldPressed : Theme.field)
  readonly property color splitColor: active
    ? (secondaryPressed ? Theme.toggleOnStrong : Qt.lighter(root.tileColor, 1.05))
    : ((secondaryPressed || menuOpen) ? Theme.fieldAlt : Qt.lighter(root.tileColor, 1.03))

  Rectangle {
    anchors.fill: parent
    radius: root.tileRadius
    color: root.tileColor
    border.width: 1
    border.color: root.active
      ? Qt.rgba(1, 1, 1, 0.12)
      : (root.menuOpen ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08))
  }

  Item {
    anchors.top: parent.top
    anchors.topMargin: root.splitInset
    anchors.bottom: parent.bottom
    anchors.bottomMargin: root.splitInset
    anchors.right: parent.right
    anchors.rightMargin: root.splitInset
    width: Math.max(0, root.splitWidth - root.splitInset)
    clip: true

    Rectangle {
      x: -root.tileRadius
      width: parent.width + root.tileRadius
      height: parent.height
      radius: root.tileRadius - root.splitInset
      color: root.splitColor
    }
  }

  Rectangle {
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    anchors.rightMargin: root.splitWidth
    width: 1
    color: root.active ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
  }

  Row {
    anchors.fill: parent
    anchors.leftMargin: 13
    anchors.rightMargin: 13
    spacing: 10

    Ui.UiIcon {
      id: primaryIcon

      anchors.verticalCenter: parent.verticalCenter
      name: root.iconName
      strokeColor: root.active ? Theme.textOnAccent : Theme.text
    }

    Ui.UiText {
      width: Math.max(0, parent.width - root.splitWidth - primaryIcon.implicitWidth)
      anchors.verticalCenter: parent.verticalCenter
      text: root.title
      size: "sm"
      tone: root.active ? "onAccent" : "primary"
      font.weight: Font.DemiBold
      elide: Text.ElideRight
    }

    Item {
      width: root.splitWidth
      height: parent.height

      Ui.UiIcon {
        anchors.centerIn: parent
		anchors.horizontalCenterOffset: -9
        width: 18
        height: 18
        name: root.menuOpen ? "chevron-down" : "chevron-right"
        strokeColor: root.active ? Theme.textOnAccent : Theme.text
      }
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
