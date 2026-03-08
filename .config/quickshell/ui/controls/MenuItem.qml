import QtQuick
import "../primitives" as Ui
import "../../theme"

Item {
  id: root

  property string iconName: "wifi"
  property string title: ""
  property string subtitle: ""
  property string actionText: ""
  property bool actionTextOnHover: true
  property string trailingIconName: ""
  property bool active: false
  property string activeStyle: "accent"
  property bool dividerVisible: false
  property bool compact: false
  signal clicked()

  width: parent ? parent.width : implicitWidth
  implicitWidth: 1
  implicitHeight: compact || subtitle === "" ? 42 : 50
  opacity: enabled ? 1 : 0.45
  readonly property bool accentActive: active && activeStyle === "accent"
  readonly property bool subtleActive: active && activeStyle === "subtle"
  readonly property bool indicatorActive: active && activeStyle === "indicator"

  Rectangle {
    anchors.fill: parent
    radius: 12
    color: root.accentActive
      ? Theme.toggleOn
      : (root.subtleActive ? Theme.field : (touchArea.pressed ? Theme.fieldAlt : "transparent"))
    border.width: root.accentActive || root.subtleActive ? 1 : 0
    border.color: root.accentActive ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08)
  }

  Row {
    anchors.fill: parent
    anchors.leftMargin: 14
    anchors.rightMargin: 14
    spacing: 14

    Item {
      width: root.iconName !== "" ? 20 : 0
      height: parent.height

      Ui.UiIcon {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.iconName !== ""
        name: root.iconName
        strokeColor: root.accentActive ? Theme.textOnAccent : Theme.text
      }
    }

    Column {
      width: Math.max(0, parent.width - trailingSlot.width - (root.iconName !== "" ? 56 : 22))
      anchors.verticalCenter: parent.verticalCenter
      spacing: root.compact ? 0 : 1

      Ui.UiText {
        text: root.title
        size: "sm"
        tone: root.accentActive ? "onAccent" : "primary"
        font.weight: Font.DemiBold
        elide: Text.ElideRight
      }

      Ui.UiText {
        text: root.subtitle
        visible: !root.compact && text !== ""
        size: "xs"
        tone: root.accentActive ? "onAccent" : "muted"
        opacity: root.accentActive ? 0.9 : 0.96
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
        visible: text !== "" && (!root.actionTextOnHover || touchArea.containsMouse)
        size: "xs"
        tone: root.accentActive ? "onAccent" : "muted"
        font.weight: Font.DemiBold
      }

      Ui.UiIcon {
        id: trailingGlyph

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        name: root.trailingIconName
        visible: name !== ""
        strokeColor: root.accentActive
          ? Theme.textOnAccent
          : (root.indicatorActive ? Theme.accent : Theme.text)
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
    visible: root.dividerVisible && !root.accentActive && !root.subtleActive
  }

  MouseArea {
    id: touchArea

    anchors.fill: parent
    enabled: root.enabled
    hoverEnabled: true
    onClicked: root.clicked()
  }
}
