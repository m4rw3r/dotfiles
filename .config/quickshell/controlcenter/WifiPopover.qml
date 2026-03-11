pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../theme"
import "../ui/primitives"
import "../ui/controls" as Controls
import "../ui/patterns" as Patterns

Patterns.HeroSheetPopover {
  id: popover

  required property var controller
  required property var wifiService

  visible: controller ? controller.expandedSection === "wifi" : false
  iconName: "wifi"
  title: controller ? controller.wifiTileTitle() : "Wi-Fi"
  subtitle: controller ? controller.wifiHeroHint() : ""
  hasStatus: wifiService ? wifiService.ready : false
  statusActive: wifiService ? wifiService.ready && wifiService.enabled && wifiService.hardwareEnabled : false
  statusBusy: wifiService ? wifiService.busy : false
  statusToggleEnabled: wifiService ? wifiService.ready && !wifiService.busy && wifiService.hardwareEnabled : false
  onStatusClicked: controller.toggleWifiEnabled()

  Column {
    width: parent.width
    spacing: Theme.gapSm

    Column {
      width: parent.width
      spacing: Theme.gapXs

      UiText {
        visible: popover.controller && popover.controller.wifiLoading && popover.controller.initialLoadDeadlineElapsed
        text: "Loading Wi-Fi..."
        size: "xs"
        tone: "subtle"
      }

      UiText {
        visible: popover.wifiService && !popover.wifiService.hardwareEnabled
        text: "Wi-Fi hardware is blocked."
        size: "xs"
        tone: "accent"
        wrapMode: Text.WordWrap
      }

      UiText {
        visible: popover.wifiService && popover.wifiService.lastError !== ""
        text: popover.wifiService ? popover.wifiService.lastError : ""
        size: "xs"
        tone: "accent"
        wrapMode: Text.WordWrap
      }
    }

    Column {
      id: wifiNetworksSection

      width: parent.width
      spacing: Theme.nudge
      visible: popover.wifiService && popover.wifiService.ready && popover.wifiService.enabled && popover.wifiService.networks.length > 0

      readonly property int visibleRowCount: 6
      readonly property real scrollIndicatorHeight: Theme.iconGlyphSm
      readonly property real viewportMaxHeight: Theme.controlMd * visibleRowCount + Theme.nudge * (visibleRowCount - 1)
      readonly property bool networkListOverflowing: wifiNetworkViewport.contentHeight > wifiNetworkViewport.height + 1
      readonly property bool networkListHasMoreAbove: networkListOverflowing && wifiNetworkViewport.contentY > 1
      readonly property bool networkListHasMoreBelow: networkListOverflowing
        && wifiNetworkViewport.contentY + wifiNetworkViewport.height < wifiNetworkViewport.contentHeight - 1

      Item {
        width: parent.width
        height: wifiNetworksSection.scrollIndicatorHeight

        UiIcon {
          anchors.horizontalCenter: parent.horizontalCenter
          width: parent.height
          height: parent.height
          name: "chevron-up"
          strokeColor: Theme.textSubtle
          opacity: wifiNetworksSection.networkListHasMoreAbove ? 0.8 : 0
        }
      }

      Flickable {
        id: wifiNetworkViewport

        width: parent.width
        height: Math.min(wifiNetworkContent.implicitHeight, wifiNetworksSection.viewportMaxHeight)
        clip: true
        contentWidth: width
        contentHeight: wifiNetworkContent.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
          policy: ScrollBar.AsNeeded
        }

        Column {
          id: wifiNetworkContent

          width: wifiNetworkViewport.width
          spacing: Theme.nudge

          Repeater {
            model: popover.wifiService && popover.wifiService.enabled ? popover.wifiService.networks.length : 0

            delegate: Controls.PopoverMenuAction {
              id: wifiRow

              required property int index
              readonly property var network: popover.wifiService.networks[index]

              width: parent.width
              visible: !!network
              title: network ? network.ssid : ""
              subtitle: network && popover.controller ? popover.controller.wifiNetworkSubtitle(network) : ""
              actionText: network && !network.active ? "Connect" : ""
              trailingIconName: network && network.active ? "check" : ""
              trailingIconColor: Theme.text
              active: network && network.active
              enabled: !!network && !popover.wifiService.busy
              onClicked: popover.controller.beginWifiConnect(network)
            }
          }
        }
      }

      Item {
        width: parent.width
        height: wifiNetworksSection.scrollIndicatorHeight

        UiIcon {
          anchors.horizontalCenter: parent.horizontalCenter
          width: parent.height
          height: parent.height
          name: "chevron-down"
          strokeColor: Theme.textSubtle
          opacity: wifiNetworksSection.networkListHasMoreBelow ? 0.8 : 0
        }
      }
    }

    UiSurface {
      visible: popover.controller && popover.controller.wifiPasswordTarget !== ""
      width: parent.width
      implicitHeight: passwordColumn.implicitHeight + Theme.insetLg
      tone: "panelOverlay"
      outlined: false
      radius: Theme.radiusLg
      border.width: Theme.stroke
      border.color: Qt.rgba(1, 1, 1, 0.08)

      Column {
        id: passwordColumn

        width: parent.width - Theme.insetLg
        anchors.left: parent.left
        anchors.leftMargin: Theme.insetSm
        anchors.top: parent.top
        anchors.topMargin: Theme.insetSm
        spacing: Theme.gapXs

        UiText {
          text: popover.controller ? `Password required for ${popover.controller.wifiPasswordTarget}` : ""
          size: "xs"
          font.weight: Font.DemiBold
          wrapMode: Text.WordWrap
        }

        TextField {
          id: wifiPasswordField

          width: parent.width
          height: Theme.controlMd
          echoMode: TextInput.Password
          color: Theme.text
          placeholderText: "Network password"
          placeholderTextColor: Theme.textSubtle
          selectionColor: Theme.selection
          selectedTextColor: Theme.textOnAccent
          font.family: Theme.fontFamily
          font.pixelSize: Theme.textSm
          onTextChanged: popover.controller.wifiPassword = text
          onVisibleChanged: {
            if (visible) {
              text = popover.controller.wifiPassword;
              forceActiveFocus();
            }
          }
          Binding on text {
            when: !wifiPasswordField.activeFocus
            value: popover.controller ? popover.controller.wifiPassword : ""
          }
          background: Rectangle {
            radius: Theme.radiusMd
            color: Theme.fieldAlt
            border.width: Theme.stroke
            border.color: Theme.divider
          }
        }

        Row {
          spacing: Theme.gapXs

          Controls.Button {
            text: "Connect"
            active: true
            enabled: popover.controller && popover.controller.wifiPassword !== "" && !popover.wifiService.busy
            onClicked: popover.controller.submitWifiPassword()
          }

          Controls.Button {
            text: "Cancel"
            onClicked: {
              popover.controller.wifiPasswordTarget = "";
              popover.controller.wifiPassword = "";
            }
          }
        }
      }
    }

    UiText {
      visible: popover.wifiService && popover.wifiService.ready && popover.wifiService.enabled && popover.wifiService.networks.length === 0 && !popover.wifiService.busy
      text: "No networks available."
      size: "xs"
      tone: "subtle"
    }

    Column {
      width: parent.width
      spacing: 4

      Controls.Divider {
        horizontalInset: Theme.controlSm / 2
      }

      Controls.PopoverMenuAction {
        width: parent.width
        title: popover.wifiService && popover.wifiService.enabled ? "Turn Off" : "Turn On"
        enabled: popover.wifiService && popover.wifiService.ready && !popover.wifiService.busy
        onClicked: popover.wifiService.setEnabledState(!popover.wifiService.enabled)
      }

      Controls.PopoverMenuAction {
        width: parent.width
        title: popover.wifiService && popover.wifiService.busy ? "Refreshing" : "Rescan"
        enabled: popover.wifiService && popover.wifiService.ready && popover.wifiService.enabled && !popover.wifiService.busy
        onClicked: popover.wifiService.scan()
      }
    }
  }
}
