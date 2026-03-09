import QtQuick
import "../primitives" as Ui
import "../../theme"

Ui.UiSurface {
  id: root

  property string iconName: "chevron-right"
  property bool active: false
  property bool circular: false
  property bool interactive: true
  property string variant: "filled"
  property int iconSize: 20
  property color iconColor: {
    if (!enabled) return Theme.textSubtle;
    if (variant === "minimal") return active ? Theme.text : Theme.textMuted;
    return active ? Theme.textOnAccent : Theme.iconSecondary;
  }
  signal clicked()

  width: implicitWidth
  implicitWidth: variant === "minimal" ? 24 : (circular ? 36 : 44)
  implicitHeight: variant === "minimal" ? 24 : (circular ? 36 : 44)
  tone: "field"
  outlined: false
  radius: variant === "minimal" ? 0 : (circular ? width / 2 : 19)
  pressed: interactive && touchArea.pressed
  opacity: enabled ? 1 : 0.45
  color: {
    if (variant === "minimal") return "transparent";
    if (active) return Theme.toggleOn;
    return touchArea.pressed ? Theme.fieldPressed : Theme.field;
  }

  border.width: variant === "minimal" ? 0 : 1
  border.color: active ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08)

  Ui.UiIcon {
    anchors.centerIn: parent
    width: root.iconSize
    height: root.iconSize
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
