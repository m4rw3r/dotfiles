import QtQuick
import "../primitives" as Ui
import "../../theme"

Item {
  id: root

  property string iconName: "wifi"
  property string title: ""
  property bool active: false
  signal clicked()

  implicitWidth: parent ? Math.floor((parent.width - 10) / 2) : 180
  implicitHeight: 44
  opacity: enabled ? 1 : 0.5

  readonly property bool pressed: touchArea.pressed
  readonly property real tileRadius: 18
  readonly property color tileColor: active
    ? (pressed ? Theme.toggleOnStrong : Theme.toggleOn)
    : (pressed ? Theme.fieldPressed : Theme.field)

  Rectangle {
    anchors.fill: parent
    radius: root.tileRadius
    color: root.tileColor
    border.width: 1
    border.color: root.active ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08)
  }

  Row {
    anchors.fill: parent
    anchors.leftMargin: 13
    anchors.rightMargin: 13
    spacing: 10

    Ui.UiIcon {
      anchors.verticalCenter: parent.verticalCenter
      name: root.iconName
      strokeColor: root.active ? Theme.textOnAccent : Theme.text
    }

    Ui.UiText {
      width: Math.max(0, parent.width - 32)
      anchors.verticalCenter: parent.verticalCenter
      text: root.title
      size: "md"
      tone: root.active ? "onAccent" : "primary"
      font.weight: Font.DemiBold
      elide: Text.ElideRight
    }
  }

  MouseArea {
    id: touchArea

    anchors.fill: parent
    enabled: root.enabled
    onClicked: root.clicked()
  }
}
