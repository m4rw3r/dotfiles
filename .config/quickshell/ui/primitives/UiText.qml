import QtQuick
import "../../theme"

Text {
  id: root

  property string tone: "primary"
  property string size: "md"

  color: {
    if (tone === "muted") return Theme.textMuted;
    if (tone === "subtle") return Theme.textSubtle;
    if (tone === "accent") return Theme.accentStrong;
    if (tone === "onAccent") return Theme.textOnAccent;
    return Theme.text;
  }

  font.family: Theme.fontFamily
  font.pixelSize: {
    if (size === "xs") return Theme.textXs;
    if (size === "sm") return Theme.textSm;
    if (size === "lg") return Theme.textLg;
    if (size === "xl") return Theme.textXl;
    return Theme.textMd;
  }
}
