pragma ComponentBehavior: Bound

import QtQuick
import "../theme"
import "../ui/primitives"
import "../ui/patterns" as Patterns

Item {
  id: footer

  required property var controller
  readonly property bool pressed: notificationFooterTouchArea.pressed
  readonly property color backgroundColor: pressed ? Theme.fieldPressed : Theme.field

  width: parent ? parent.width : implicitWidth
  implicitHeight: Theme.tileHeight

  Patterns.QuickTileFrame {
    anchors.fill: parent
    iconName: footer.controller.unreadNotificationCount > 0 ? "bell-dot" : "bell"
    title: ""
    backgroundColor: footer.backgroundColor
    borderColor: Theme.borderSubtle
    iconColor: Theme.text
    textTone: "primary"
    trailingWidth: Theme.iconGlyphSm

    UiIcon {
      anchors.centerIn: parent
      width: Theme.iconGlyphSm
      height: Theme.iconGlyphSm
      name: "chevron-right"
      strokeColor: Theme.textSubtle
    }
  }

  Column {
    anchors.left: parent.left
    anchors.leftMargin: Theme.gapSm + Theme.iconGlyphSm + Theme.gapXs
    anchors.right: parent.right
    anchors.rightMargin: Theme.gapSm + Theme.iconGlyphSm + Theme.gapXs
    anchors.verticalCenter: parent.verticalCenter
    spacing: Theme.nudge

    Item {
      id: notificationSourceRow

      width: parent.width
      height: sourceLabel.implicitHeight
      z: 2

      UiText {
        id: sourceLabel

        anchors.left: parent.left
        anchors.right: unreadBadge.left
        anchors.rightMargin: unreadBadge.visible ? Theme.gapXs : 0
        anchors.verticalCenter: parent.verticalCenter
        text: footer.controller.footerNotificationEntry && footer.controller.notificationCenter ? footer.controller.notificationCenter.appLabel(footer.controller.footerNotificationEntry) : "Notifications"
        size: "xs"
        tone: footer.controller.notificationCount > 0 ? "primary" : "muted"
        font.weight: Font.DemiBold
        elide: Text.ElideRight
      }

      Rectangle {
        id: unreadBadge

        visible: footer.controller.unreadNotificationCount > 0
        width: visible ? Math.max(Theme.iconGlyphMd, unreadBadgeLabel.implicitWidth + Theme.gapSm) : 0
        height: visible ? Theme.iconGlyphMd : 0
        radius: height / 2
        color: footer.controller.notificationsCriticalUnread ? Theme.accent : Theme.toggleOn
        anchors.right: parent.right
        y: Math.round((footer.height - height) / 2) - 7

        UiText {
          id: unreadBadgeLabel

          anchors.centerIn: parent
          text: footer.controller.unreadNotificationCount > 99 ? "99+" : String(footer.controller.unreadNotificationCount)
          size: "xs"
          tone: "onAccent"
          font.weight: Font.DemiBold
        }
      }
    }

    Item {
      id: notificationSummaryRow

      width: parent.width
      height: summaryLabel.implicitHeight
      z: 1

      UiText {
        id: summaryLabel

        width: parent.width
        text: footer.controller.footerNotificationEntry && footer.controller.notificationCenter ? footer.controller.notificationCenter.summaryLabel(footer.controller.footerNotificationEntry) : "No notifications"
        size: "sm"
        tone: footer.controller.notificationCount > 0 ? "primary" : "subtle"
        elide: Text.ElideRight
        textFormat: Text.PlainText
      }

      Item {
        visible: unreadBadge.visible
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: unreadBadge.width + Theme.controlMd
        clip: true
        z: 1

        Rectangle {
          anchors.centerIn: parent
          width: parent.height
          height: parent.width
          rotation: -90
          transformOrigin: Item.Center
          color: "transparent"
          gradient: Gradient {
            GradientStop {
              position: 0.0
              color: Qt.rgba(footer.backgroundColor.r, footer.backgroundColor.g, footer.backgroundColor.b, 0)
            }
            GradientStop {
              position: 1.0
              color: Qt.rgba(footer.backgroundColor.r, footer.backgroundColor.g, footer.backgroundColor.b, 1)
            }
          }
        }
      }
    }
  }

  Rectangle {
    visible: footer.controller.notificationsCriticalUnread
    width: 8
    height: 8
    radius: 4
    color: Theme.accentStrong
    x: Theme.gapSm + Theme.iconGlyphSm - width * 0.35
    y: Math.round((parent.height - Theme.iconGlyphSm) / 2) - height * 0.25
  }

  MouseArea {
    id: notificationFooterTouchArea

    anchors.fill: parent
    onClicked: footer.controller.toggleNotificationsSection()
  }
}
