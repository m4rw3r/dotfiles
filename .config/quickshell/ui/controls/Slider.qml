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
  property alias leadingAccessory: leadingAccessoryHost.data
  property alias trailingAccessory: trailingAccessoryHost.data
  readonly property bool hasLeadingAccessory: leadingAccessoryHost.children.length > 0
  readonly property bool hasTrailingAccessory: trailingAccessoryHost.children.length > 0
  property int leadingSlotWidth: (root.showIcon || root.hasLeadingAccessory) ? Theme.controlAccessorySlot : 0
  property int trailingSlotWidth: (root.showValueText || root.hasTrailingAccessory) ? Theme.controlAccessorySlot : 0
  signal valueMoved(real value)
  signal valueCommitted(real value)

  implicitWidth: parent ? parent.width : 0
  implicitHeight: Theme.controlSm

  onValueChanged: {
    if (!control.pressed) dragValue = value;
  }

  Item {
    id: leadingSlot

    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: root.leadingSlotWidth

    Item {
      id: leadingAccessoryHost

      anchors.fill: parent
    }

    Ui.UiIcon {
      anchors.centerIn: parent
      visible: root.showIcon && !root.hasLeadingAccessory
      name: root.iconName
      strokeColor: root.enabled ? Theme.text : Theme.textSubtle
    }
  }

  Item {
    id: trailingSlot

    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: root.trailingSlotWidth

    Item {
      id: trailingAccessoryHost

      anchors.fill: parent
    }

    Ui.UiText {
      id: valueLabel

      anchors.centerIn: parent
      text: root.valueText
      visible: root.showValueText && !root.hasTrailingAccessory
      size: "xs"
      tone: "muted"
      font.weight: Font.DemiBold
    }
  }

  Item {
    anchors.left: leadingSlot.right
    anchors.leftMargin: leadingSlot.width > 0 ? Theme.gapXs : 0
    anchors.right: trailingSlot.left
    anchors.rightMargin: trailingSlot.width > 0 ? Theme.gapXs : 0
    anchors.top: parent.top
    anchors.bottom: parent.bottom

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
        height: Theme.gapXs
        radius: height / 2
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
        width: Theme.iconGlyphMd
        height: Theme.iconGlyphMd
        radius: width / 2
        color: Theme.text
        border.width: Theme.stroke
        border.color: Qt.rgba(0, 0, 0, 0.18)
      }
    }
  }
}
