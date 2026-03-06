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
  implicitHeight: root.subtitle === "" ? 44 : 58

  readonly property bool highlighted: active || (highlightExpanded && expanded)
  readonly property real splitWidth: expandable ? 52 : 0
  readonly property bool pressed: primaryTouch.pressed || (expandable && secondaryTouch.pressed)
  readonly property color tileColor: highlighted
    ? (pressed ? Theme.toggleOnStrong : Theme.toggleOn)
    : (pressed ? Theme.fieldPressed : Theme.toggleOff)
  readonly property color splitColor: highlighted ? Theme.toggleOnStrong : Theme.fieldAlt

  Rectangle {
    anchors.fill: parent
    radius: 19
    color: root.tileColor
    border.width: 1
    border.color: root.highlighted ? Qt.rgba(1, 1, 1, 0.08) : Theme.divider
  }

  Rectangle {
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    width: root.expandable ? 52 : 0
    radius: 19
    color: root.splitColor
    visible: root.expandable
  }

  Rectangle {
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    anchors.rightMargin: root.splitWidth
    width: 1
    color: root.active ? Qt.rgba(1, 1, 1, 0.14) : Theme.divider
    visible: root.expandable
  }

  Row {
    anchors.fill: parent
    anchors.leftMargin: 16
    anchors.rightMargin: 12
    spacing: 10

    Ui.UiIcon {
      anchors.verticalCenter: parent.verticalCenter
      name: root.iconName
      strokeColor: root.highlighted ? Theme.textOnAccent : Theme.textMuted
    }

    Column {
      width: Math.max(0, parent.width - (root.expandable ? 78 : 34))
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
      width: 40
      height: parent.height

      Ui.UiIcon {
        anchors.centerIn: parent
        visible: root.expandable
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
    onClicked: root.primaryClicked()
  }

  MouseArea {
    id: secondaryTouch

    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    width: root.expandable ? 52 : 0
    enabled: root.expandable
    onClicked: root.secondaryClicked()
  }
}
