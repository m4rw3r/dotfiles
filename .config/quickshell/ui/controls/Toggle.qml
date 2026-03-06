import QtQuick
import "../primitives" as Ui
import "../../theme"

Ui.UiSurface {
  id: root

  property string text: ""
  property string description: ""
  property string iconName: ""
  property bool checked: false
  signal clicked()
  signal toggled(bool checked)

  width: parent ? parent.width : implicitWidth
  implicitWidth: 1
  implicitHeight: description === "" ? 44 : 52
  tone: "fieldAlt"
  outlined: false
  radius: 18
  pressed: touchArea.pressed
  opacity: enabled ? 1 : 0.45

  border.width: 1
  border.color: checked ? Theme.toggleOn : Theme.divider

  Row {
    anchors.fill: parent
    anchors.leftMargin: 14
    anchors.rightMargin: 14
    spacing: 12

    Ui.UiIcon {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.iconName !== ""
      name: root.iconName
      strokeColor: Theme.iconSecondary
    }

    Column {
      width: Math.max(0, parent.width - switchTrack.width - (root.iconName !== "" ? 52 : 32))
      anchors.verticalCenter: parent.verticalCenter
      spacing: root.description === "" ? 0 : 2

      Ui.UiText {
        text: root.text
        size: "sm"
        font.weight: Font.DemiBold
      }

      Ui.UiText {
        text: root.description
        visible: text !== ""
        size: "xs"
        tone: "muted"
        elide: Text.ElideRight
      }
    }

    Rectangle {
      id: switchTrack

      anchors.verticalCenter: parent.verticalCenter
      width: 38
      height: 22
      radius: height / 2
      color: root.checked ? Theme.toggleOn : Theme.toggleOff

      Rectangle {
        width: 16
        height: 16
        radius: width / 2
        x: root.checked ? parent.width - width - 3 : 3
        y: 3
        color: Theme.textOnAccent
      }
    }
  }

  MouseArea {
    id: touchArea

    anchors.fill: parent
    enabled: root.enabled
    onClicked: {
      root.clicked();
      root.toggled(!root.checked);
    }
  }
}
