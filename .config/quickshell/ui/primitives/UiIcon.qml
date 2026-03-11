import QtQuick
import QtQuick.Controls.impl as QtQuickControlsImpl
import "../../icons" as Icons
import "../../theme"

Item {
  id: root

  property string name: "chevron-right"
  property color strokeColor: Theme.text
  property color iconColor: strokeColor
  property real stroke: 1.75

  implicitWidth: Theme.iconGlyphSm
  implicitHeight: Theme.iconGlyphSm

  readonly property url sourceUrl: Icons.IconResolver.glyphSource(name)

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
