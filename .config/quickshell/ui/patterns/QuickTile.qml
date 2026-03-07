import QtQuick
import "../primitives" as Ui
import "../../theme"

Item {
  id: root

  property string iconName: "wifi"
  property string title: ""
  property string subtitle: ""
  property bool active: false
  property bool expanded: false
  property bool expandable: true
  property bool highlightExpanded: false
  signal primaryClicked()
  signal secondaryClicked()

  implicitWidth: parent ? Math.floor((parent.width - 10) / 2) : 180
  implicitHeight: root.subtitle === "" ? 44 : 56
  opacity: enabled ? 1 : 0.5

  readonly property bool highlighted: active || (highlightExpanded && expanded)
  readonly property real tileRadius: 18
  readonly property real splitWidth: expandable ? (highlighted ? 38 : 42) : 0
  readonly property real splitInset: expandable ? 1 : 0
  readonly property bool pressed: primaryTouch.pressed || (expandable && secondaryTouch.pressed)
  readonly property color tileColor: highlighted
    ? (pressed ? Theme.toggleOnStrong : Theme.toggleOn)
    : (pressed ? Theme.fieldPressed : Theme.field)
  readonly property color splitColor: highlighted ? Qt.lighter(root.tileColor, 1.06) : Qt.lighter(root.tileColor, 1.05)

  Rectangle {
    anchors.fill: parent
    radius: root.tileRadius
    color: root.tileColor
    border.width: 1
    border.color: root.highlighted ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08)
  }

  Item {
    anchors.top: parent.top
    anchors.topMargin: root.splitInset
    anchors.bottom: parent.bottom
    anchors.bottomMargin: root.splitInset
    anchors.right: parent.right
    anchors.rightMargin: root.splitInset
    width: Math.max(0, root.splitWidth - root.splitInset)
    visible: root.expandable
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
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    anchors.rightMargin: root.splitWidth
    width: 1
    color: root.highlighted ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
    visible: root.expandable
  }

  Row {
    anchors.fill: parent
    anchors.leftMargin: 13
    anchors.rightMargin: 10
    spacing: 10

    Ui.UiIcon {
      anchors.verticalCenter: parent.verticalCenter
      name: root.iconName
      strokeColor: root.highlighted ? Theme.textOnAccent : Theme.textMuted
    }

    Column {
      width: Math.max(0, parent.width - (root.expandable ? (root.splitWidth + 24) : 32))
      anchors.verticalCenter: parent.verticalCenter
      spacing: root.subtitle === "" ? 0 : 2

      Ui.UiText {
        width: parent.width
        text: root.title
        size: "sm"
        tone: root.highlighted ? "onAccent" : "primary"
        font.weight: Font.DemiBold
        elide: Text.ElideRight
      }

      Ui.UiText {
        width: parent.width
        visible: root.subtitle !== ""
        text: root.subtitle
        size: "xs"
        tone: root.highlighted ? "onAccent" : "muted"
        opacity: root.highlighted ? 0.88 : 0.96
        elide: Text.ElideRight
      }
    }

    Item {
      visible: root.expandable
      width: 30
      height: parent.height

      Ui.UiIcon {
        anchors.centerIn: parent
        visible: root.expandable
        width: 18
        height: 18
        name: root.expanded ? "chevron-down" : "chevron-right"
        strokeColor: root.highlighted ? Theme.textOnAccent : Theme.iconSecondary
      }
    }
  }

  MouseArea {
    id: primaryTouch

    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    anchors.rightMargin: root.splitWidth
    enabled: root.enabled
    onClicked: root.primaryClicked()
  }

  MouseArea {
    id: secondaryTouch

    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    width: root.splitWidth
    enabled: root.enabled && root.expandable
    onClicked: root.secondaryClicked()
  }
}
