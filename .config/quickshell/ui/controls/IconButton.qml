import QtQuick
import "../primitives" as Ui
import "../../theme"

Ui.UiSurface {
  id: root

  property string iconName: "chevron-right"
  property bool active: false
  property bool circular: false
  property bool interactive: true
  property color iconColor: active ? Theme.textOnAccent : Theme.iconSecondary
  signal clicked()

  width: implicitWidth
  implicitWidth: circular ? 46 : 44
  implicitHeight: circular ? 46 : 44
  tone: active ? "toggleOn" : "fieldAlt"
  outlined: false
  radius: circular ? width / 2 : 19
  pressed: interactive && touchArea.pressed
  opacity: enabled ? 1 : 0.45

  border.width: 1
  border.color: active ? Qt.rgba(1, 1, 1, 0.08) : Theme.divider

  Ui.UiIcon {
    anchors.centerIn: parent
    name: root.iconName
    strokeColor: root.iconColor
  }

  MouseArea {
    id: touchArea

    anchors.fill: parent
    enabled: root.enabled && root.interactive
    onClicked: root.clicked()
  }
}
