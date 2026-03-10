import QtQuick
import "../primitives" as Ui
import "../../theme"

Item {
  id: root

  property string title: ""
  property string subtitle: ""
  property string actionText: ""
  property string trailingIconName: ""
  property color trailingIconColor: Theme.textMuted
  property bool active: false
  signal clicked()

  width: parent ? parent.width : implicitWidth
  implicitWidth: 1
  implicitHeight: subtitle !== "" ? Theme.controlMd : Theme.controlSm
  opacity: enabled ? 1 : 0.5

  Rectangle {
    anchors.fill: parent
    radius: Theme.radiusMd
    color: root.active
      ? Qt.rgba(1, 1, 1, 0.06)
      : (touchArea.pressed ? Qt.rgba(1, 1, 1, 0.035) : "transparent")
    border.width: root.active ? Theme.stroke : 0
    border.color: Qt.rgba(1, 1, 1, 0.1)
  }

  Column {
    width: Math.max(0, parent.width - trailingSlot.width - Theme.controlMd)
    anchors.left: parent.left
    anchors.leftMargin: Theme.gapSm
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.subtitle !== "" ? Theme.nudge : 0

    Ui.UiText {
      width: parent.width
      text: root.title
      size: "md"
      font.weight: Font.Medium
      elide: Text.ElideRight
    }

    Ui.UiText {
      width: parent.width
      visible: text !== ""
      text: root.subtitle
      size: "xs"
      tone: "muted"
      elide: Text.ElideRight
    }
  }

  Item {
    id: trailingSlot

    anchors.right: parent.right
    anchors.rightMargin: Theme.gapSm
    anchors.verticalCenter: parent.verticalCenter
    width: Math.max(actionLabel.visible ? actionLabel.implicitWidth : 0, trailingGlyph.visible ? trailingGlyph.implicitWidth : 0)
    height: parent.height

    Ui.UiText {
      id: actionLabel

      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      visible: text !== ""
      text: root.actionText
      size: "xs"
      tone: "muted"
      font.weight: Font.DemiBold
    }

    Ui.UiIcon {
      id: trailingGlyph

      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      visible: name !== ""
      width: 16
      height: 16
      name: root.trailingIconName
      strokeColor: root.trailingIconColor
    }
  }

  MouseArea {
    id: touchArea

    anchors.fill: parent
    enabled: root.enabled
    hoverEnabled: true
    onClicked: root.clicked()
  }
}
