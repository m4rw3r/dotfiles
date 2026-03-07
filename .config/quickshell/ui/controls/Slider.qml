import QtQuick
import QtQuick.Controls as QtControls
import "../primitives" as Ui
import "../../theme"

Item {
  id: root

  property string iconName: "speaker"
  property bool showIcon: true
  property real from: 0
  property real to: 1
  property real stepSize: 0
  property real value: 0
  property real dragValue: value
  property string valueText: ""
  property bool showValueText: false
  signal valueMoved(real value)
  signal valueCommitted(real value)

  implicitWidth: parent ? parent.width : 0
  implicitHeight: 40

  onValueChanged: {
    if (!control.pressed) dragValue = value;
  }

  Row {
    anchors.fill: parent
    spacing: 10

    Ui.UiIcon {
      id: startIcon

      anchors.verticalCenter: parent.verticalCenter
      visible: root.showIcon
      name: root.iconName
      strokeColor: root.enabled ? Theme.text : Theme.textSubtle
    }

    Item {
      width: parent.width - (root.showIcon ? startIcon.width : 0) - detailSlot.width - parent.spacing * (root.showIcon ? 2 : 1)
      height: parent.height

      QtControls.Slider {
        id: control

        anchors.fill: parent
        from: root.from
        to: root.to
        stepSize: root.stepSize
        value: root.dragValue
        enabled: root.enabled

        onValueChanged: {
          if (!pressed) return;
          root.dragValue = value;
          root.valueMoved(value);
        }

        onPressedChanged: {
          if (!pressed) root.valueCommitted(root.dragValue);
        }

        background: Rectangle {
          x: control.leftPadding
          y: control.topPadding + control.availableHeight / 2 - height / 2
          width: control.availableWidth
          height: 7
          radius: 3.5
          color: Theme.sliderTrack

          Rectangle {
            width: Math.max(parent.height, control.visualPosition * parent.width)
            height: parent.height
            radius: parent.radius
            color: Theme.sliderFill
          }
        }

        handle: Rectangle {
          x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
          y: control.topPadding + control.availableHeight / 2 - height / 2
          width: 20
          height: 20
          radius: 10
          color: Theme.text
          border.width: 1
          border.color: Qt.rgba(0, 0, 0, 0.18)
        }
      }
    }

    Item {
      id: detailSlot

      width: root.showValueText ? valueLabel.implicitWidth : 0
      height: parent.height

      Ui.UiText {
        id: valueLabel

        anchors.verticalCenter: parent.verticalCenter
        text: root.valueText
        visible: root.showValueText
        size: "xs"
        tone: "muted"
        font.weight: Font.DemiBold
      }
    }
  }
}
