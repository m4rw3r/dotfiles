import QtQuick
import "../primitives" as Ui
import "../../theme"

Item {
  id: root

  property string iconName: "wifi"
  property string title: ""
  property string subtitle: ""
  property string actionText: ""
  property string trailingIconName: ""
  property bool active: false
  property bool dividerVisible: false
  property bool compact: false
  signal clicked()

  width: parent ? parent.width : implicitWidth
  implicitWidth: 1
  implicitHeight: compact || subtitle === "" ? 42 : 50
  opacity: enabled ? 1 : 0.45

  Rectangle {
    anchors.fill: parent
    radius: 12
    color: root.active ? Theme.toggleOn : (touchArea.pressed ? Theme.fieldAlt : "transparent")
    border.width: root.active ? 1 : 0
    border.color: root.active ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
  }

  Row {
    anchors.fill: parent
    anchors.leftMargin: 14
    anchors.rightMargin: 14
    spacing: 14

    Ui.UiIcon {
      anchors.verticalCenter: parent.verticalCenter
      name: root.iconName
      strokeColor: root.active ? Theme.textOnAccent : Theme.iconSecondary
    }

    Column {
      width: Math.max(0, parent.width - trailingSlot.width - 42)
      anchors.verticalCenter: parent.verticalCenter
      spacing: root.compact ? 0 : 1

      Ui.UiText {
        text: root.title
        size: "sm"
        tone: root.active ? "onAccent" : "primary"
        font.weight: Font.DemiBold
        elide: Text.ElideRight
      }

      Ui.UiText {
        text: root.subtitle
        visible: !root.compact && text !== ""
        size: "xs"
        tone: root.active ? "onAccent" : "muted"
        opacity: root.active ? 0.9 : 0.96
        elide: Text.ElideRight
      }
    }

    Item {
      id: trailingSlot

      width: actionLabel.visible || trailingGlyph.visible ? Math.max(actionLabel.implicitWidth, trailingGlyph.implicitWidth) : 0
      height: parent.height

      Ui.UiText {
        id: actionLabel

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        text: root.actionText
        visible: text !== ""
        size: "xs"
        tone: root.active ? "onAccent" : "muted"
        font.weight: Font.DemiBold
      }

      Ui.UiIcon {
        id: trailingGlyph

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        name: root.trailingIconName
        visible: name !== ""
        strokeColor: root.active ? Theme.textOnAccent : Theme.iconSecondary
      }
    }
  }

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.leftMargin: 18
    anchors.rightMargin: 18
    height: 1
    color: Theme.divider
    visible: root.dividerVisible && !root.active
  }

  MouseArea {
    id: touchArea

    anchors.fill: parent
    enabled: root.enabled
    onClicked: root.clicked()
  }
}
