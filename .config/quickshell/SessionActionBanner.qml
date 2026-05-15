pragma ComponentBehavior: Bound

import QtQuick
import "theme"
import "ui/controls" as Controls
import "ui/primitives"

UiSurface {
  id: banner

  required property var controller

  width: implicitWidth
  implicitWidth: Theme.popoverWidthSm + Theme.controlMd + Theme.gapLg
  implicitHeight: contentColumn.implicitHeight + Theme.insetLg
  tone: "panelOverlay"
  outlined: false
  radius: Theme.radiusLg
  border.width: Theme.stroke
  border.color: banner.controller.errorVisible ? Theme.accentStrong : Theme.border

  Column {
    id: contentColumn

    width: parent.width - Theme.insetLg
    anchors.left: parent.left
    anchors.leftMargin: Theme.insetSm
    anchors.top: parent.top
    anchors.topMargin: Theme.insetSm
    spacing: Theme.gapSm

    Row {
      width: parent.width
      spacing: Theme.gapSm

      Rectangle {
        width: Theme.controlMd
        height: Theme.controlMd
        radius: Theme.controlMd / 2
        color: banner.controller.errorVisible ? Theme.accent : Theme.field

        UiIcon {
          anchors.centerIn: parent
          name: banner.controller.actionIcon(banner.controller.errorVisible ? banner.controller.failedAction : banner.controller.busyAction)
          strokeColor: banner.controller.errorVisible ? Theme.textOnAccent : Theme.text
        }
      }

      Column {
        width: Math.max(0, parent.width - Theme.controlMd * 2 - Theme.gapLg)
        spacing: Theme.nudge

        UiText {
          width: parent.width
          text: banner.controller.errorVisible ? banner.controller.errorTitle() : banner.controller.busyTitle()
          size: "sm"
          font.weight: Font.DemiBold
          wrapMode: Text.WordWrap
        }

        UiText {
          width: parent.width
          text: banner.controller.errorVisible ? banner.controller.lastError : banner.controller.busyDescription()
          size: "xs"
          tone: banner.controller.errorVisible ? "accent" : "subtle"
          wrapMode: Text.WordWrap
        }
      }

      Controls.IconButton {
        anchors.top: parent.top
        visible: banner.controller.errorVisible
        variant: "minimal"
        iconName: "x"
        onClicked: banner.controller.dismissError()
      }
    }

    Row {
      visible: banner.controller.errorVisible
      width: parent.width
      spacing: Theme.gapXs

      Controls.Button {
        text: "Retry"
        compact: true
        enabled: banner.controller.failedAction !== "" && !banner.controller.busy
        onClicked: banner.controller.retry()
      }

      Controls.Button {
        text: "Dismiss"
        compact: true
        onClicked: banner.controller.dismissError()
      }
    }
  }
}
