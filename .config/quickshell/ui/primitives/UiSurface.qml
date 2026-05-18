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
    if (tone === "panelOverlay") return Theme.panelOverlay;
    if (tone === "raised") return Theme.panelRaised;
    if (tone === "submenu") return Theme.submenu;
    if (tone === "chip") return Theme.chip;
    if (tone === "field") return pressed ? Theme.fieldPressed : Theme.field;
    if (tone === "fieldAlt") return pressed ? Theme.fieldPressed : Theme.fieldAlt;
    if (tone === "toggleOff") return pressed ? Theme.fieldPressed : Theme.toggleOff;
    if (tone === "toggleOn") return pressed ? Theme.toggleOnStrong : Theme.toggleOn;
    if (tone === "accent") return pressed ? Theme.accentStrong : Theme.accent;
    return Theme.panel;
  }
}
