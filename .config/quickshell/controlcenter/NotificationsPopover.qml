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

  component NotificationInboxCard: UiSurface {
    id: card

    required property var entry
    readonly property bool unread: !!(entry && entry.unread)
    readonly property bool critical: !!(entry && entry.urgency === NotificationUrgency.Critical)
    readonly property string primaryActionLabel: popover.notificationCenter ? popover.notificationCenter.primaryActionLabel(entry) : ""
    readonly property string appLabel: popover.notificationCenter ? popover.notificationCenter.appLabel(entry) : "Notification"
    readonly property string summaryLabel: popover.notificationCenter ? popover.notificationCenter.summaryLabel(entry) : ""
    readonly property string bodyLabel: popover.notificationCenter ? popover.notificationCenter.bodyLabel(entry) : ""

    width: parent ? parent.width : implicitWidth
    implicitHeight: cardContent.implicitHeight + Theme.insetSm * 2
    tone: critical ? "chip" : (unread ? "field" : "fieldAlt")
    outlined: false
    radius: Theme.radiusLg
    border.width: Theme.stroke
    border.color: critical
      ? Qt.rgba(1, 1, 1, 0.16)
      : (unread ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08))

    Column {
      id: cardContent

      width: parent.width - Theme.insetLg
      anchors.left: parent.left
      anchors.leftMargin: Theme.insetSm
      anchors.top: parent.top
      anchors.topMargin: Theme.insetSm
      spacing: Theme.gapXs

      Row {
        width: parent.width
        spacing: Theme.gapSm

        Item {
          id: iconSlot

          width: Theme.controlSm
          height: Theme.controlSm

          UiSurface {
            anchors.fill: parent
            tone: card.critical ? "accent" : "field"
            radius: width / 2
            outlined: false
          }

          UiIcon {
            visible: !appIcon.visible
            anchors.centerIn: parent
            width: Theme.iconGlyphSm
            height: Theme.iconGlyphSm
            name: card.critical ? "bell-ring" : "bell"
            strokeColor: card.critical ? Theme.textOnAccent : Theme.text
          }

          ResolvedIconImage {
            id: appIcon

            visible: appIcon.source !== ""
            anchors.centerIn: iconSlot
            implicitSize: Theme.iconGlyphSm
            asynchronous: true
            mipmap: true
            icon: card.entry ? String(card.entry.appIcon || "") : ""
            desktopEntry: card.entry ? String(card.entry.desktopEntry || "") : ""
            appName: card.entry ? String(card.entry.appName || "") : ""
          }
        }

        Column {
          width: Math.max(0, parent.width - Theme.controlSm - metadataSlot.width - closeButton.implicitWidth - Theme.gapSm * 3)
          spacing: Theme.nudge

          UiText {
            width: parent.width
            text: card.appLabel
            size: "xs"
            tone: "muted"
            font.weight: Font.DemiBold
            elide: Text.ElideRight
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

        Item {
          id: metadataSlot

          width: ageLabel.implicitWidth + (unreadIndicator.visible ? unreadIndicator.width + Theme.gapXs : 0)
          height: Math.max(ageLabel.implicitHeight, unreadIndicator.visible ? unreadIndicator.height : 0)

          Rectangle {
            id: unreadIndicator

            visible: card.unread
            width: 8
            height: 8
            radius: 4
            color: card.critical ? Theme.accentStrong : Theme.toggleOn
            anchors.left: parent.left
            anchors.top: parent.top
          }

          UiText {
            id: ageLabel

            anchors.right: parent.right
            anchors.top: parent.top
            text: popover.notificationCenter ? popover.notificationCenter.ageLabel(card.entry) : ""
            size: "xs"
            tone: "subtle"
          }
        }

        Controls.IconButton {
          id: closeButton

          variant: "minimal"
          iconName: "x"
          onClicked: {
            if (popover.notificationCenter) popover.notificationCenter.forgetEntry(card.entry);
          }
        }
      }

      UiText {
        visible: text !== ""
        width: parent.width
        text: card.bodyLabel
        size: "xs"
        tone: "subtle"
        wrapMode: Text.WordWrap
        maximumLineCount: 3
        elide: Text.ElideRight
        textFormat: Text.PlainText
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
            if (popover.notificationCenter) popover.notificationCenter.invokePrimaryAction(card.entry);
          }
        }
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

    UiSurface {
      width: parent.width
      implicitHeight: groupHeaderContent.implicitHeight + Theme.insetSm * 2
      tone: groupSection.group && groupSection.group.criticalUnreadCount > 0
        ? "chip"
        : (groupSection.group && groupSection.group.unreadCount > 0 ? "field" : "fieldAlt")
      outlined: false
      radius: Theme.radiusLg
      border.width: Theme.stroke
      border.color: groupSection.group && groupSection.group.unreadCount > 0
        ? Qt.rgba(1, 1, 1, 0.12)
        : Qt.rgba(1, 1, 1, 0.08)

      Column {
        id: groupHeaderContent

        width: parent.width - Theme.insetLg
        anchors.left: parent.left
        anchors.leftMargin: Theme.insetSm
        anchors.top: parent.top
        anchors.topMargin: Theme.insetSm
        spacing: Theme.nudge

        Row {
          width: parent.width
          spacing: Theme.gapXs

          UiText {
            width: Math.max(0, parent.width - groupClearButton.implicitWidth - Theme.gapXs)
            text: groupSection.group ? groupSection.group.appName : "Notifications"
            size: "xs"
            tone: "muted"
            font.weight: Font.DemiBold
            elide: Text.ElideRight
          }

          Controls.IconButton {
            id: groupClearButton

            visible: groupSection.expandable
            variant: "minimal"
            iconName: "x"
            onClicked: popover.controller.clearNotificationGroup(groupSection.group.key)
          }
        }

        Item {
          width: parent.width
          height: Math.max(groupSummary.implicitHeight, Math.max(groupMeta.implicitHeight, groupChevron.height))

          UiText {
            id: groupSummary

            anchors.left: parent.left
            anchors.right: groupMeta.left
            anchors.rightMargin: Theme.gapXs
            anchors.verticalCenter: parent.verticalCenter
            text: popover.notificationCenter ? popover.notificationCenter.summaryLabel(groupSection.latestEntry) : ""
            size: "sm"
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            textFormat: Text.PlainText
          }

          UiText {
            id: groupMeta

            anchors.right: groupChevron.left
            anchors.rightMargin: Theme.gapXs
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

          MouseArea {
            anchors.fill: parent
            enabled: groupSection.expandable
            onClicked: popover.controller.toggleNotificationGroup(groupSection.group.key)
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
        spacing: Theme.gapXs

        Repeater {
          model: groupSection.expandable && groupSection.group ? groupSection.group.entries : []

          delegate: NotificationInboxCard {
            required property var modelData
            entry: modelData
          }
        }
      }
    }
  }

  Column {
    width: parent.width
    spacing: Theme.gapSm

    Flickable {
      id: notificationViewport

      width: parent.width
      height: Math.min(notificationContentColumn.implicitHeight, popover.controller ? popover.controller.notificationViewportMaxHeight : Theme.controlMd * 6)
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
        spacing: Theme.gapSm

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
