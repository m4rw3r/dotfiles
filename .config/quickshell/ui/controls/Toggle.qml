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
  implicitHeight: description === "" ? Theme.controlMd : Theme.controlMd + Theme.gapXs
  tone: "fieldAlt"
  outlined: false
  radius: Theme.radiusMd
  pressed: touchArea.pressed
  opacity: enabled ? 1 : 0.45

  border.width: Theme.stroke
  border.color: checked ? Theme.toggleOn : Theme.divider

  Row {
    anchors.fill: parent
    anchors.leftMargin: Theme.gapSm
    anchors.rightMargin: Theme.gapSm
    spacing: Theme.gapSm

    Ui.UiIcon {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.iconName !== ""
      name: root.iconName
      strokeColor: Theme.text
    }

    Column {
      width: Math.max(
        0,
        parent.width - switchTrack.width - (root.iconName !== "" ? Theme.controlMd + Theme.gapXs : Theme.controlSm)
      )
      anchors.verticalCenter: parent.verticalCenter
      spacing: root.description === "" ? 0 : Theme.stroke

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
      width: Theme.controlSm
      height: Theme.iconGlyphMd
      radius: height / 2
      color: root.checked ? Theme.toggleOn : Theme.toggleOff

      Rectangle {
        width: Theme.iconGlyphSm
        height: Theme.iconGlyphSm
        radius: width / 2
        x: root.checked ? parent.width - width - Theme.nudge : Theme.nudge
        y: Theme.nudge
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
