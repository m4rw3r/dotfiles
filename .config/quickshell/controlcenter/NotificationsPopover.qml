pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Services.Notifications
import "../theme"
import "../ui/primitives"
import "../ui/controls" as Controls
import "../ui/patterns" as Patterns

Patterns.HeroSheetPopover {
  id: popover

  required property var controller
  readonly property var notificationCenter: controller ? controller.notificationCenter : null

  visible: controller ? controller.notificationsOpen : false
  iconName: popover.controller && popover.controller.notificationsCriticalUnread ? "bell-ring" : "bell"
  title: "Notifications"
  subtitle: popover.controller && popover.controller.unreadNotificationCount > 0 && notificationCenter
    ? notificationCenter.unreadCountLabel()
    : "You're all caught up."

  function withAlpha(color, alpha) {
    return Qt.rgba(color.r, color.g, color.b, alpha);
  }

  component NotificationSectionLabel: UiText {
    size: "xs"
    tone: "muted"
    font.weight: Font.DemiBold
  }

  component NotificationRowFrame: Item {
    id: frame

    property bool active: false
    property bool critical: false
    property bool clickable: true
    property int horizontalPadding: Theme.gapSm
    property int verticalPadding: Theme.insetSm
    default property alias content: frameColumn.data
    signal clicked()

    width: parent ? parent.width : implicitWidth
    implicitWidth: 1
    implicitHeight: Math.max(Theme.controlSm, frameColumn.implicitHeight + verticalPadding * 2)
    opacity: enabled ? 1 : 0.6

    Rectangle {
      anchors.fill: parent
      radius: Theme.radiusMd
      color: frame.critical
        ? Theme.chip
        : (frame.active ? Qt.rgba(1, 1, 1, 0.06) : (frameTouch.pressed ? Qt.rgba(1, 1, 1, 0.035) : "transparent"))
      border.width: frame.critical || frame.active ? Theme.stroke : 0
      border.color: frame.critical ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.1)
    }

    MouseArea {
      id: frameTouch

      anchors.fill: parent
      enabled: frame.enabled && frame.clickable
      hoverEnabled: true
      onClicked: frame.clicked()
    }

    Column {
      id: frameColumn

      width: parent.width - frame.horizontalPadding * 2
      anchors.left: parent.left
      anchors.leftMargin: frame.horizontalPadding
      anchors.top: parent.top
      anchors.topMargin: frame.verticalPadding
      spacing: Theme.gapXs
    }
  }

  component NotificationSourceBadge: Item {
    id: badge

    property var entry: null
    property bool critical: false
    property bool active: false

    width: Theme.controlSm
    height: Theme.controlSm

    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: badge.critical ? Theme.accent : (badge.active ? Theme.toggleOn : Theme.field)
      border.width: badge.critical || badge.active ? 0 : Theme.stroke
      border.color: Qt.rgba(1, 1, 1, 0.08)
    }

    UiIcon {
      visible: !appIcon.visible
      anchors.centerIn: parent
      width: Theme.iconGlyphSm
      height: Theme.iconGlyphSm
      name: badge.critical ? "bell-ring" : "bell"
      strokeColor: badge.critical || badge.active ? Theme.textOnAccent : Theme.text
    }

    ResolvedIconImage {
      id: appIcon

      visible: source !== ""
      anchors.centerIn: parent
      implicitSize: Theme.iconGlyphSm
      asynchronous: true
      mipmap: true
      icon: badge.entry ? String(badge.entry.appIcon || "") : ""
      desktopEntry: badge.entry ? String(badge.entry.desktopEntry || "") : ""
      appName: badge.entry ? String(badge.entry.appName || "") : ""
    }
  }

  component NotificationInboxCard: UiSurface {
    id: card

    required property var entry
    property bool showSourceBadge: true
    readonly property bool unread: !!(entry && entry.unread)
    readonly property bool critical: !!(entry && entry.urgency === NotificationUrgency.Critical)
    readonly property string primaryActionLabel: popover.notificationCenter ? popover.notificationCenter.primaryActionLabel(entry) : ""
    readonly property string appLabel: popover.notificationCenter ? popover.notificationCenter.appLabel(entry) : "Notification"
    readonly property string summaryLabel: popover.notificationCenter ? popover.notificationCenter.summaryLabel(entry) : ""
    readonly property string bodyLabel: popover.notificationCenter ? popover.notificationCenter.bodyLabel(entry) : ""
    readonly property bool hasFocusTarget: popover.notificationCenter ? popover.notificationCenter.entryHasFocusTarget(entry) : false
    readonly property bool hasBody: bodyLabel !== ""
    readonly property bool hasPrimaryAction: primaryActionLabel !== ""
    readonly property bool rowClickable: hasFocusTarget || hasPrimaryAction
    property bool dividerVisible: false
    property int frameHorizontalPadding: Theme.gapSm
    readonly property real detailInset: showSourceBadge ? Theme.controlSm + Theme.gapSm : 0

    width: parent ? parent.width : implicitWidth
    implicitHeight: cardFrame.implicitHeight
    color: "transparent"
    outlined: false
    radius: Theme.radiusMd
    border.width: 0

    NotificationRowFrame {
      id: cardFrame

      width: parent.width
      critical: card.critical
      clickable: card.rowClickable
      horizontalPadding: card.frameHorizontalPadding
      onClicked: {
        if (popover.notificationCenter) popover.notificationCenter.activateEntry(card.entry);
      }

      Row {
        width: parent.width
        spacing: card.showSourceBadge ? Theme.gapSm : 0

        NotificationSourceBadge {
          id: cardBadge

          width: card.showSourceBadge ? Theme.controlSm : 0
          height: width
          visible: card.showSourceBadge
          entry: card.entry
          critical: card.critical
        }

        Column {
          width: Math.max(
            0,
            parent.width - closeButton.implicitWidth
            - (card.showSourceBadge ? cardBadge.width + Theme.gapSm * 2 : 0)
          )
          spacing: Theme.nudge

          Item {
            width: parent.width
            height: Math.max(sourceLabel.implicitHeight, ageLabel.implicitHeight, sourceUnreadDot.visible ? sourceUnreadDot.height : 0)

            Rectangle {
              id: sourceUnreadDot

              visible: card.unread
              width: 8
              height: 8
              radius: 4
              color: card.critical ? Theme.accentStrong : Theme.toggleOn
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            UiText {
              id: sourceLabel

              anchors.left: sourceUnreadDot.visible ? sourceUnreadDot.right : parent.left
              anchors.leftMargin: sourceUnreadDot.visible ? Theme.gapXs : 0
              anchors.right: ageLabel.left
              anchors.rightMargin: Theme.gapXs
              anchors.verticalCenter: parent.verticalCenter
              text: card.appLabel
              size: "xs"
              tone: "muted"
              font.weight: Font.DemiBold
              elide: Text.ElideRight
            }

            UiText {
              id: ageLabel

              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: popover.notificationCenter ? popover.notificationCenter.ageLabel(card.entry) : ""
              size: "xs"
              tone: "subtle"
            }
          }

          UiText {
            width: parent.width
            text: card.summaryLabel
            size: "sm"
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            textFormat: Text.PlainText
          }
        }

        Controls.IconButton {
          id: closeButton

          anchors.verticalCenter: parent.verticalCenter
          variant: "minimal"
          iconName: "x"
          onClicked: {
            if (popover.notificationCenter) popover.notificationCenter.forgetEntry(card.entry);
          }
        }
      }

      Item {
        visible: card.hasBody
        width: parent.width
        height: card.hasBody ? bodyText.implicitHeight : 0

        UiText {
          id: bodyText

          anchors.left: parent.left
          anchors.leftMargin: card.detailInset
          anchors.right: parent.right
          text: card.bodyLabel
          size: "xs"
          tone: "subtle"
          wrapMode: Text.WordWrap
          maximumLineCount: 3
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }
      }

      Item {
        visible: card.hasPrimaryAction
        width: parent.width
        height: card.hasPrimaryAction ? actionButton.implicitHeight : 0

        Controls.Button {
          id: actionButton

          anchors.left: parent.left
          anchors.leftMargin: card.detailInset
          visible: card.hasPrimaryAction
          compact: true
          active: true
          text: card.primaryActionLabel
          onClicked: {
            if (popover.notificationCenter) popover.notificationCenter.invokePrimaryAction(card.entry);
          }
        }
      }

      Controls.Divider {
        visible: card.dividerVisible
        horizontalInset: 0
      }
    }
  }

  component NotificationGroupSection: Column {
    id: groupSection

    required property var group
    readonly property bool expandable: !!group && group.entryCount > 1
    readonly property bool expanded: expandable && popover.controller && popover.controller.isNotificationGroupExpanded(group.key)
    readonly property var latestEntry: group ? group.latestEntry : null

    width: parent ? parent.width : implicitWidth
    spacing: Theme.gapXs

    NotificationRowFrame {
      id: groupHeader

      width: parent.width
      critical: !!(groupSection.group && groupSection.group.criticalUnreadCount > 0)
      clickable: groupSection.expandable && !!popover.controller
      onClicked: {
        if (popover.controller) popover.controller.toggleNotificationGroup(groupSection.group.key);
      }

      Item {
        width: parent.width
        height: Math.max(groupBadge.height, groupInfo.implicitHeight, groupTrailing.height, groupClearButton.implicitHeight)

        NotificationSourceBadge {
          id: groupBadge

          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          entry: groupSection.latestEntry
          critical: !!(groupSection.group && groupSection.group.criticalUnreadCount > 0)
        }

        Controls.IconButton {
          id: groupClearButton

          visible: groupSection.expandable
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          variant: "minimal"
          iconName: "x"
          onClicked: {
            if (popover.controller) popover.controller.clearNotificationGroup(groupSection.group.key);
          }
        }

        Item {
          id: groupTrailing

          anchors.right: groupClearButton.visible ? groupClearButton.left : parent.right
          anchors.rightMargin: groupClearButton.visible ? Theme.gapXs : 0
          anchors.verticalCenter: parent.verticalCenter
          width: groupMeta.implicitWidth + (groupChevron.visible ? groupChevron.width + Theme.gapXs : 0)
          height: Math.max(groupMeta.implicitHeight, groupChevron.height)

          UiText {
            id: groupMeta

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: {
              if (!groupSection.group) return "";
              if (groupSection.group.entryCount === 1) return "1 message";
              return `${groupSection.group.entryCount} messages`;
            }
            size: "xs"
            tone: groupSection.group && groupSection.group.criticalUnreadCount > 0 ? "accent" : "subtle"
          }

          UiIcon {
            id: groupChevron

            visible: groupSection.expandable
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.iconGlyphSm
            height: Theme.iconGlyphSm
            name: groupSection.expanded ? "chevron-down" : "chevron-right"
            strokeColor: Theme.textSubtle
          }
        }

        Column {
          id: groupInfo

          anchors.left: groupBadge.right
          anchors.leftMargin: Theme.gapSm
          anchors.right: groupTrailing.left
          anchors.rightMargin: Theme.gapSm
          anchors.verticalCenter: parent.verticalCenter
          spacing: Theme.nudge

          Item {
            width: parent.width
            height: Math.max(groupSourceLabel.implicitHeight, groupUnreadDot.visible ? groupUnreadDot.height : 0)

            Rectangle {
              id: groupUnreadDot

              visible: !!(groupSection.group && groupSection.group.unreadCount > 0)
              width: 8
              height: 8
              radius: 4
              color: groupSection.group && groupSection.group.criticalUnreadCount > 0 ? Theme.accentStrong : Theme.toggleOn
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            UiText {
              id: groupSourceLabel

              anchors.left: groupUnreadDot.visible ? groupUnreadDot.right : parent.left
              anchors.leftMargin: groupUnreadDot.visible ? Theme.gapXs : 0
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: groupSection.group ? groupSection.group.appName : "Notifications"
              size: "xs"
              tone: "muted"
              font.weight: Font.DemiBold
              elide: Text.ElideRight
            }
          }

          UiText {
            width: parent.width
            text: popover.notificationCenter ? popover.notificationCenter.summaryLabel(groupSection.latestEntry) : ""
            size: "sm"
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            textFormat: Text.PlainText
          }
        }
      }
    }

    Item {
      width: parent.width
      height: groupSection.expanded ? groupCards.implicitHeight : 0
      clip: true

      Behavior on height {
        NumberAnimation {
          duration: Theme.motionBase
          easing.type: Easing.OutCubic
        }
      }

      Column {
        id: groupCards

        width: parent.width
        spacing: 0

        Repeater {
          model: groupSection.expandable && groupSection.group ? groupSection.group.entries : []

          delegate: NotificationInboxCard {
            required property int index
            required property var modelData
            entry: modelData
            showSourceBadge: false
            frameHorizontalPadding: 0
            dividerVisible: index < groupSection.group.entries.length - 1
          }
        }
      }
    }
  }

  Column {
    id: notificationListColumn

    width: parent.width
    spacing: Theme.gapSm

    readonly property real scrollIndicatorHeight: Theme.controlSm
    readonly property bool notificationListOverflowing: notificationViewport.contentHeight > notificationViewport.height + 1
    readonly property bool notificationListHasMoreAbove: notificationListOverflowing && notificationViewport.contentY > 1
    readonly property bool notificationListHasMoreBelow: notificationListOverflowing
      && notificationViewport.contentY + notificationViewport.height < notificationViewport.contentHeight - 1

    NotificationSectionLabel {
      visible: popover.controller && popover.controller.notificationCount > 0
      width: parent.width
      text: "Recent"
    }

    Item {
      width: parent.width
      height: Math.min(notificationContentColumn.implicitHeight, popover.controller ? popover.controller.notificationViewportMaxHeight : Theme.controlMd * 6)

      Flickable {
        id: notificationViewport

        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: notificationContentColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
          policy: ScrollBar.AsNeeded
        }

        Column {
          id: notificationContentColumn

          width: notificationViewport.width
          spacing: Theme.gapXs

          Item {
            width: parent.width
            height: emptyNotificationsState.visible ? emptyNotificationsState.implicitHeight : 0
            visible: !popover.controller || popover.controller.notificationCount === 0

            Column {
              id: emptyNotificationsState

              width: parent.width
              spacing: Theme.gapXs

              UiText {
                width: parent.width
                text: "No notifications"
                size: "sm"
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
              }

              UiText {
                width: parent.width
                text: "New messages will show up here."
                size: "xs"
                tone: "subtle"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
              }
            }
          }

          Repeater {
            model: popover.notificationCenter ? popover.notificationCenter.groupedEntries : []

            delegate: Item {
              required property var modelData

              width: notificationContentColumn.width
              height: modelData && modelData.entryCount === 1
                ? singleNotificationCard.implicitHeight
                : groupedNotificationSection.implicitHeight

              NotificationInboxCard {
                id: singleNotificationCard

                visible: !!parent.modelData && parent.modelData.entryCount === 1
                width: parent.width
                entry: parent.modelData ? parent.modelData.latestEntry : null
              }

              NotificationGroupSection {
                id: groupedNotificationSection

                visible: !!parent.modelData && parent.modelData.entryCount > 1
                width: parent.width
                group: parent.modelData
              }
            }
          }
        }
      }

      Item {
        anchors.top: parent.top
        width: parent.width
        height: notificationListColumn.scrollIndicatorHeight
        visible: popover.controller && popover.controller.notificationCount > 0

        Rectangle {
          anchors.fill: parent
          color: "transparent"
          opacity: notificationListColumn.notificationListHasMoreAbove ? 1 : 0
          gradient: Gradient {
            GradientStop { position: 0.0; color: popover.withAlpha(Theme.submenu, 1) }
            GradientStop { position: 1.0; color: popover.withAlpha(Theme.submenu, 0) }
          }
        }

        UiIcon {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.top
          width: Theme.iconGlyphSm
          height: Theme.iconGlyphSm
          name: "chevron-up"
          strokeColor: Theme.textSubtle
          opacity: notificationListColumn.notificationListHasMoreAbove ? 0.8 : 0
        }
      }

      Item {
        anchors.bottom: parent.bottom
        width: parent.width
        height: notificationListColumn.scrollIndicatorHeight
        visible: popover.controller && popover.controller.notificationCount > 0

        Rectangle {
          anchors.fill: parent
          color: "transparent"
          opacity: notificationListColumn.notificationListHasMoreBelow ? 1 : 0
          gradient: Gradient {
            GradientStop { position: 0.0; color: popover.withAlpha(Theme.submenu, 0) }
            GradientStop { position: 1.0; color: popover.withAlpha(Theme.submenu, 1) }
          }
        }

        UiIcon {
          id: notificationMoreIndicator

          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          width: Theme.iconGlyphSm
          height: Theme.iconGlyphSm
          name: "chevron-down"
          strokeColor: Theme.textSubtle
          opacity: notificationListColumn.notificationListHasMoreBelow ? 0.8 : 0
        }
      }
    }

    Column {
      width: parent.width
      spacing: 4
      visible: popover.controller && popover.controller.notificationCount > 0

      Controls.Divider {
        horizontalInset: Theme.controlSm / 2
      }

      Controls.PopoverMenuAction {
        width: parent.width
        title: "Clear All"
        onClicked: {
          if (popover.notificationCenter) popover.notificationCenter.clearEntries();
        }
      }
    }
  }
}
