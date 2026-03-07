import QtQuick
import "../primitives" as Ui
import "../../theme"

Ui.UiSurface {
  id: root

  property string text: ""
  property bool active: false
  property bool compact: false
  property string variant: "secondary"
  signal clicked()

  width: implicitWidth
  implicitWidth: Math.max(compact ? 84 : 104, label.implicitWidth + 30)
  implicitHeight: compact ? 34 : 40
  tone: "field"
  outlined: false
  radius: 18
  pressed: touchArea.pressed
  opacity: enabled ? 1 : 0.45
  color: active || variant === "accent"
    ? (touchArea.pressed ? Theme.accentStrong : Theme.accent)
    : (touchArea.pressed ? Theme.fieldPressed : Theme.field)

  border.width: 1
  border.color: active || variant === "accent" ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08)

  Ui.UiText {
    id: label

    anchors.centerIn: parent
    text: root.text
    size: "sm"
    tone: root.active || root.variant === "accent" ? "onAccent" : "primary"
    font.weight: Font.DemiBold
  }

  MouseArea {
    id: touchArea

    anchors.fill: parent
    enabled: root.enabled
    onClicked: root.clicked()
  }
}
