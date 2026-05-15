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

  signal pressed(int index)
  signal activated(var entry)

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
      color: root.selected ? Theme.textOnAccent : Theme.text
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
