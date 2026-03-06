import QtQuick
import "../../theme"

Rectangle {
  id: root

  property string tone: "panel"
  property bool outlined: false
  property bool pressed: false

  radius: Theme.radiusMd
  border.width: outlined ? 1 : 0
  border.color: Theme.border

  color: {
    if (tone === "raised") return Theme.panelRaised;
    if (tone === "field") return pressed ? Theme.fieldPressed : Theme.field;
    if (tone === "accent") return Theme.accent;
    return Theme.panel;
  }
}
