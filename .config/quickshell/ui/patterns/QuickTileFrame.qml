import QtQuick
import "../primitives" as Ui
import "../../theme"

Item {
  id: root

  property string iconName: "wifi"
  property string title: ""
  property color backgroundColor: Theme.field
  property color borderColor: Qt.rgba(1, 1, 1, 0.08)
  property color iconColor: Theme.text
  property string textTone: "primary"
  property bool split: false
  property int trailingWidth: 0
  property int splitWidth: Theme.tileSplitWidth
  property int splitInset: Theme.stroke
  property color splitColor: "transparent"
  property color separatorColor: Qt.rgba(1, 1, 1, 0.08)
  property real tileRadius: Theme.radiusMd
  default property alias trailingContent: trailingSlot.data

  implicitWidth: parent ? Math.floor((parent.width - Theme.gapSm) / 2) : Theme.popoverWidthSm
  implicitHeight: Theme.tileHeight
  opacity: enabled ? 1 : 0.5

  Rectangle {
    anchors.fill: parent
    radius: root.tileRadius
    color: root.backgroundColor
    border.width: Theme.stroke
    border.color: root.borderColor
  }

  Item {
    visible: root.split
    anchors.top: parent.top
    anchors.topMargin: root.splitInset
    anchors.bottom: parent.bottom
    anchors.bottomMargin: root.splitInset
    anchors.right: parent.right
    anchors.rightMargin: root.splitInset
    width: Math.max(0, root.splitWidth - root.splitInset)
    clip: true

    Rectangle {
      x: -root.tileRadius
      width: parent.width + root.tileRadius
      height: parent.height
      radius: root.tileRadius - root.splitInset
      color: root.splitColor
    }
  }

  Rectangle {
    visible: root.split
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    anchors.rightMargin: root.splitWidth
    width: Theme.stroke
    color: root.separatorColor
  }

  Ui.UiIcon {
    id: leadingIcon

    anchors.left: parent.left
    anchors.leftMargin: Theme.gapSm
    anchors.verticalCenter: parent.verticalCenter
    name: root.iconName
    strokeColor: root.iconColor
  }

  Item {
    id: trailingSlot

    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    anchors.rightMargin: root.split ? 0 : Theme.gapSm
    width: root.trailingWidth
  }

  Ui.UiText {
    anchors.left: leadingIcon.right
    anchors.leftMargin: Theme.gapXs
    anchors.right: trailingSlot.left
    anchors.rightMargin: trailingSlot.width > 0 ? Theme.gapXs : 0
    anchors.verticalCenter: parent.verticalCenter
    text: root.title
    size: "md"
    tone: root.textTone
    font.weight: Font.DemiBold
    elide: Text.ElideRight
  }
}
