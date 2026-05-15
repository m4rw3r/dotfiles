pragma ComponentBehavior: Bound

import QtQuick
import "theme"
import "ui/primitives"

Item {
  id: root

  required property var entry
  required property int absoluteIndex
  property bool selected: false
  readonly property bool hasEntry: !!entry
  readonly property string entryIcon: hasEntry && entry.icon ? String(entry.icon) : ""
  readonly property string entryName: hasEntry && entry.name ? entry.name : ""
  readonly property string entryGenericName: hasEntry && entry.genericName ? entry.genericName : ""

  function withAlpha(color, alpha) {
    return Qt.rgba(color.r, color.g, color.b, alpha);
  }

  signal pressed(int index)
  signal activated(var entry)

  Rectangle {
    anchors.centerIn: parent
    width: Math.max(0, parent.width - Theme.gapSm)
    height: Math.max(0, parent.height - Theme.gapXs)
    radius: Math.min(Theme.radiusLg, height / 2)
    opacity: root.selected ? (tileTouch.pressed ? 0.72 : 0.9) : 0
    scale: root.selected ? 1 : 0.96
    color: root.withAlpha(Theme.accent, 0.18)
    border.width: 1
    border.color: root.withAlpha(Theme.accentStrong, root.selected ? 0.42 : 0)

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.motionFast
        easing.type: Easing.OutCubic
      }
    }

    Behavior on scale {
      NumberAnimation {
        duration: Theme.motionFast
        easing.type: Easing.OutCubic
      }
    }
  }

  MouseArea {
    id: tileTouch
    anchors.fill: parent
    enabled: root.hasEntry
    onPressed: root.pressed(root.absoluteIndex)
    onClicked: root.activated(root.entry)
  }

  Column {
    width: parent.width
    anchors.centerIn: parent
    spacing: 7
    opacity: tileTouch.pressed ? 0.62 : (root.selected ? 1 : 0.82)
    scale: root.selected ? 1.05 : 1

    Behavior on scale {
      NumberAnimation {
        duration: Theme.motionFast
        easing.type: Easing.OutCubic
      }
    }

    ResolvedIconImage {
      anchors.horizontalCenter: parent.horizontalCenter
      implicitSize: root.selected ? Theme.launcherTileIconMd : Theme.launcherTileIconSm
      asynchronous: true
      mipmap: true
      icon: root.entryIcon
      desktopEntry: root.hasEntry ? String(root.entry.id || "") : ""
      appName: root.entryName
      fallback: "application-x-executable"
    }

    UiText {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      maximumLineCount: 2
      elide: Text.ElideRight
      text: root.entryName
      color: Theme.text
      size: "md"
      font.weight: Font.DemiBold
    }

    UiText {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      visible: root.entryGenericName !== ""
      text: root.entryGenericName
      color: root.selected ? Theme.textMuted : Theme.textSubtle
      size: "sm"
    }
  }
}
