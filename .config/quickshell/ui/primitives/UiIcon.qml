import QtQuick
import QtQuick.Controls.impl as QtQuickControlsImpl
import "../../theme"

Item {
  id: root

  property string name: "chevron-right"
  property color strokeColor: Theme.text
  property color iconColor: strokeColor
  property real stroke: 1.75

  implicitWidth: Theme.iconGlyphSm
  implicitHeight: Theme.iconGlyphSm

  readonly property var aliases: ({
    "restart": "rotate-cw",
    "logout": "log-out",
    "speaker": "volume-2",
    "speaker-muted": "volume-x",
    "battery": "battery-medium"
  })
  readonly property string resolvedName: aliases[name] !== undefined ? aliases[name] : name
  readonly property url sourceUrl: resolvedName === "" ? "" : Qt.resolvedUrl(`../../icons/${resolvedName}.svg`)

  QtQuickControlsImpl.IconImage {
    anchors.fill: parent
    source: root.sourceUrl
    color: root.iconColor
    asynchronous: false
    mipmap: true
    sourceSize.width: Math.max(Theme.iconGlyphMd, Math.round(width * 2))
    sourceSize.height: Math.max(Theme.iconGlyphMd, Math.round(height * 2))
  }
}
