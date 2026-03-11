pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Notifications
import Quickshell.Widgets
import "theme"
import "ui/controls" as Controls
import "ui/primitives"

FocusScope {
  id: root

  property var notificationCenter: null
  property bool suspended: false

  implicitWidth: toastColumn.implicitWidth
  implicitHeight: toastColumn.implicitHeight

  component ToastCard: UiSurface {
    id: card

    required property int toastUid
    required property var notificationCenter
    property bool suspended: false
    readonly property int centerRevision: notificationCenter ? notificationCenter.revision : 0
    readonly property var entry: {
      const revision = centerRevision;
      return notificationCenter ? notificationCenter.entryForUid(toastUid) : null;
    }
    readonly property bool critical: !!(entry && entry.urgency === NotificationUrgency.Critical)
    readonly property string primaryActionLabel: notificationCenter ? notificationCenter.primaryActionLabel(entry) : ""
    readonly property int timeoutMs: notificationCenter ? notificationCenter.toastTimeoutMs(entry) : 0
    readonly property bool autoDismiss: timeoutMs > 0

    visible: !!entry
    width: parent ? parent.width : implicitWidth
    implicitHeight: toastContent.implicitHeight + Theme.insetLg
    tone: "panelOverlay"
    outlined: false
    radius: Theme.radiusLg
    border.width: Theme.stroke
    border.color: critical ? Theme.accentStrong : Qt.rgba(1, 1, 1, 0.12)
    opacity: entry ? 1 : 0

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.motionFast
        easing.type: Easing.OutCubic
      }
    }

    transform: Translate {
      y: card.opacity < 1 ? -Theme.gapSm : 0
    }

    Column {
      id: toastContent

      width: parent.width - Theme.insetLg
      anchors.left: parent.left
      anchors.leftMargin: Theme.insetSm
      anchors.top: parent.top
      anchors.topMargin: Theme.insetSm
      spacing: Theme.gapSm

      Row {
        width: parent.width
        spacing: Theme.gapSm

        Item {
          width: Theme.controlMd
          height: Theme.controlMd

          UiSurface {
            anchors.fill: parent
            tone: card.critical ? "accent" : "field"
            radius: width / 2
            outlined: false
          }

          UiIcon {
            visible: !toastIcon.visible
            anchors.centerIn: parent
            width: Theme.iconGlyphMd
            height: Theme.iconGlyphMd
            name: card.critical ? "bell-ring" : "bell"
            strokeColor: card.critical ? Theme.textOnAccent : Theme.text
          }

          IconImage {
            id: toastIcon

            visible: source !== ""
            anchors.centerIn: parent
            implicitSize: Theme.iconGlyphMd
            asynchronous: true
            mipmap: true
            source: card.entry ? card.entry.appIcon : ""
          }
        }

        Column {
          width: Math.max(0, parent.width - Theme.controlMd - dismissButton.implicitWidth - Theme.gapLg)
          spacing: Theme.nudge

          Row {
            width: parent.width

            UiText {
              width: Math.max(0, parent.width - toastAge.implicitWidth - Theme.gapXs)
              text: card.notificationCenter ? card.notificationCenter.appLabel(card.entry) : "Notification"
              size: "xs"
              tone: "muted"
              font.weight: Font.DemiBold
              elide: Text.ElideRight
            }

            UiText {
              id: toastAge

              text: card.notificationCenter ? card.notificationCenter.ageLabel(card.entry) : ""
              size: "xs"
              tone: "subtle"
            }
          }

          UiText {
            width: parent.width
            text: card.notificationCenter ? card.notificationCenter.summaryLabel(card.entry) : ""
            size: "sm"
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            textFormat: Text.PlainText
          }

          UiText {
            visible: text !== ""
            width: parent.width
            text: card.notificationCenter ? card.notificationCenter.bodyLabel(card.entry) : ""
            size: "xs"
            tone: "subtle"
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            textFormat: Text.PlainText
          }
        }

        Controls.IconButton {
          id: dismissButton

          variant: "minimal"
          iconName: "x"
          onClicked: {
            if (card.notificationCenter) card.notificationCenter.closeLive(card.toastUid);
          }
        }
      }

      Row {
        visible: actionButton.visible
        spacing: Theme.gapXs

        Controls.Button {
          id: actionButton

          visible: card.primaryActionLabel !== ""
          compact: true
          text: card.primaryActionLabel
          onClicked: {
            if (card.notificationCenter) card.notificationCenter.invokePrimaryAction(card.toastUid);
          }
        }
      }
    }

    Timer {
      interval: card.timeoutMs
      running: card.autoDismiss && !card.suspended && !!card.entry
      repeat: false
      onTriggered: {
        if (card.notificationCenter) card.notificationCenter.dismissToast(card.toastUid);
      }
    }
  }

  Column {
    id: toastColumn

    width: Theme.popoverWidthSm + Theme.controlMd + Theme.gapLg
    spacing: Theme.gapSm

    Repeater {
      model: root.notificationCenter ? root.notificationCenter.toastUids : []

      delegate: ToastCard {
        required property var modelData

        toastUid: Number(modelData)
        notificationCenter: root.notificationCenter
        suspended: root.suspended
      }
    }
  }
}
