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
  implicitWidth: Math.max(compact ? 82 : 102, label.implicitWidth + 28)
  implicitHeight: compact ? 34 : 40
  tone: active ? "toggleOn" : (variant === "accent" ? "accent" : "fieldAlt")
  outlined: false
  radius: 18
  pressed: touchArea.pressed
  opacity: enabled ? 1 : 0.45

  border.width: 1
  border.color: active || variant === "accent" ? Qt.rgba(1, 1, 1, 0.08) : Theme.divider

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
