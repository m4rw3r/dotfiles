import QtQuick
import "../primitives" as Ui
import "../../theme"

Item {
  id: root

  property string iconName: "gauge"
  property string title: ""
  property bool active: false
  property bool useActiveStyling: true
  property bool open: false
  signal clicked()

  implicitWidth: parent ? Math.floor((parent.width - 10) / 2) : 180
  implicitHeight: 44
  opacity: enabled ? 1 : 0.5

  readonly property bool pressed: touchArea.pressed
  readonly property bool highlighted: useActiveStyling && active
  readonly property real tileRadius: 18
  readonly property color tileColor: highlighted
    ? (pressed ? Theme.toggleOnStrong : Theme.toggleOn)
    : ((pressed || open) ? Theme.fieldAlt : Theme.field)

  Rectangle {
    anchors.fill: parent
    radius: root.tileRadius
    color: root.tileColor
    border.width: 1
    border.color: root.highlighted
      ? Qt.rgba(1, 1, 1, 0.12)
      : (root.open ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08))
  }

  Row {
    anchors.fill: parent
    anchors.leftMargin: 13
    anchors.rightMargin: 13
    spacing: 10

    Ui.UiIcon {
      anchors.verticalCenter: parent.verticalCenter
      name: root.iconName
      strokeColor: root.highlighted ? Theme.textOnAccent : Theme.text
    }

    Ui.UiText {
      width: Math.max(0, parent.width - 32)
      anchors.verticalCenter: parent.verticalCenter
      text: root.title
      size: "md"
      tone: root.highlighted ? "onAccent" : "primary"
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
