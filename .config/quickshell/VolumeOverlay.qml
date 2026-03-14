pragma ComponentBehavior: Bound

import QtQuick
import "theme"
import "ui/primitives"

Item {
  id: root

  property real value: 0
  property bool muted: false
  property bool active: false
  property real offsetX: active ? 0 : hud.implicitWidth * 0.7

  readonly property real clampedValue: Math.max(0, Math.min(1, Number(value) || 0))
  readonly property real displayedValue: muted ? 0 : clampedValue
  readonly property int percentValue: Math.round(clampedValue * 100)
  readonly property string labelText: muted ? "mute" : `${percentValue}%`
  readonly property color fillColor: muted ? Theme.textSubtle : Theme.sliderFill

  implicitWidth: hud.implicitWidth
  implicitHeight: hud.implicitHeight
  opacity: active ? 1 : 0
  visible: active || opacity > 0

  Behavior on opacity {
    NumberAnimation {
      duration: Theme.motionFast
      easing.type: Easing.OutCubic
    }
  }

  Behavior on offsetX {
    NumberAnimation {
      duration: Theme.motionBase
      easing.type: Easing.OutCubic
    }
  }

  transform: Translate {
    x: root.offsetX
  }

  UiSurface {
    id: hud

    implicitWidth: 60
    implicitHeight: 188
    tone: "panelOverlay"
    outlined: false
    radius: Theme.radiusLg
    border.width: Theme.stroke
    border.color: Qt.rgba(1, 1, 1, 0.12)

    Column {
      anchors.fill: parent
      anchors.margins: Theme.insetSm
      spacing: Theme.gapSm

      UiText {
        id: label

        anchors.horizontalCenter: parent.horizontalCenter
        text: root.labelText
        size: "xs"
        tone: root.muted ? "subtle" : "muted"
        font.weight: Font.DemiBold
      }

      Rectangle {
        id: track

        anchors.horizontalCenter: parent.horizontalCenter
        width: Theme.gapXs
        height: 104
        radius: width / 2
        color: Theme.field
        border.width: Theme.stroke
        border.color: Qt.rgba(1, 1, 1, 0.08)

        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: root.displayedValue <= 0 ? 0 : Math.max(parent.width, root.displayedValue * parent.height)
          radius: parent.radius
          color: root.fillColor
          visible: height > 0
        }
      }

      Item {
        width: 1
        height: Math.max(0, parent.height - label.implicitHeight - track.height - iconBadge.height - Theme.gapSm * 3)
      }

      UiSurface {
        id: iconBadge

        anchors.horizontalCenter: parent.horizontalCenter
        width: Theme.controlSm
        height: Theme.controlSm
        radius: width / 2
        tone: root.muted ? "fieldAlt" : "field"
        outlined: false

        UiIcon {
          anchors.centerIn: parent
          width: Theme.iconGlyphMd
          height: Theme.iconGlyphMd
          name: root.muted ? "speaker-muted" : "speaker"
          strokeColor: root.muted ? Theme.textSubtle : Theme.text
        }
      }
    }
  }
}
