pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Bluetooth
import "../theme"
import "../ui/primitives"
import "../ui/controls" as Controls
import "../ui/patterns" as Patterns

Patterns.HeroSheetPopover {
  id: popover

  required property var controller
  required property var bluetoothService

  visible: controller ? controller.expandedSection === "bluetooth" : false
  sectionSpacing: Theme.gapSm
  iconName: "bluetooth"
  title: controller ? controller.bluetoothTileTitle() : "Bluetooth"
  subtitle: controller ? controller.bluetoothTileSubtitle() : ""
  hasStatus: !!bluetoothService.adapter
  statusActive: !!(bluetoothService.adapter && bluetoothService.enabled && !bluetoothService.blocked)
  statusBusy: bluetoothService.busy
  statusToggleEnabled: !!bluetoothService.adapter && !bluetoothService.busy && (!bluetoothService.blocked || bluetoothService.unblockAvailable)
  onStatusClicked: controller.toggleBluetoothEnabled()

  Column {
    width: parent.width
    spacing: Theme.gapSm

    Column {
      width: parent.width
      spacing: Theme.gapXs
      visible: !popover.bluetoothService.adapter || popover.controller.bluetoothBlockedMessage() !== "" || popover.bluetoothService.lastError !== ""

      UiText {
        visible: !popover.bluetoothService.adapter
        text: "No Bluetooth adapter found."
        size: "xs"
        tone: "accent"
      }

      UiText {
        visible: popover.controller.bluetoothBlockedMessage() !== ""
        text: popover.controller.bluetoothBlockedMessage()
        size: "xs"
        tone: "accent"
        wrapMode: Text.WordWrap
      }

      UiText {
        visible: popover.bluetoothService.lastError !== ""
        text: popover.bluetoothService.lastError
        size: "xs"
        tone: "accent"
        wrapMode: Text.WordWrap
      }
    }

    Column {
      width: parent.width
      spacing: 4
      visible: popover.bluetoothService.enabled && popover.bluetoothService.connectedCount > 0

      UiText {
        text: "Connected Devices"
        size: "xs"
        tone: "muted"
        font.weight: Font.DemiBold
      }

      Column {
        width: parent.width
        spacing: 4

        Repeater {
          model: popover.bluetoothService.enabled ? popover.bluetoothService.devices : []

          delegate: Controls.PopoverMenuAction {
            id: connectedDeviceRow

            required property var modelData
            readonly property var device: modelData
            readonly property bool busyState: !!(device && (device.pairing || device.state === BluetoothDeviceState.Connecting))

            visible: !!(device && device.connected)
            width: parent.width
            title: popover.controller.bluetoothDeviceTitle(device)
            subtitle: popover.controller.bluetoothConnectedSubtitle(device)
            actionText: busyState ? "Working" : "Disconnect"
            active: true
            enabled: visible && !busyState
            onClicked: {
              if (busyState)
                return;
              device.disconnect();
            }
          }
        }
      }
    }

    Column {
      id: availableDevicesSection

      width: parent.width
      spacing: 4
      visible: popover.bluetoothService.enabled && popover.bluetoothService.availableCount > 0

      readonly property real scrollIndicatorHeight: Theme.controlSm
      readonly property bool scanListOverflowing: bluetoothScanViewport.contentHeight > bluetoothScanViewport.height + 1
      readonly property bool scanListHasMoreAbove: scanListOverflowing && bluetoothScanViewport.contentY > 1
      readonly property bool scanListHasMoreBelow: scanListOverflowing && bluetoothScanViewport.contentY + bluetoothScanViewport.height < bluetoothScanViewport.contentHeight - 1

      UiText {
        text: "Available Devices"
        size: "xs"
        tone: "muted"
        font.weight: Font.DemiBold
      }

      Item {
        width: parent.width
        height: Math.min(bluetoothScanContent.implicitHeight, popover.controller.bluetoothScanViewportMaxHeight)

        Flickable {
          id: bluetoothScanViewport

          anchors.fill: parent
          clip: true
          contentWidth: width
          contentHeight: bluetoothScanContent.implicitHeight
          boundsBehavior: Flickable.StopAtBounds

          ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
          }

          Column {
            id: bluetoothScanContent

            width: bluetoothScanViewport.width
            spacing: 4

            Repeater {
              model: popover.bluetoothService.enabled ? popover.bluetoothService.devices : []

              delegate: Controls.PopoverMenuAction {
                id: otherDeviceRow

                required property var modelData
                readonly property var device: modelData
                readonly property bool busyState: !!(device && (device.pairing || device.state === BluetoothDeviceState.Connecting))

                visible: !!(device && !device.connected)
                width: parent.width
                title: popover.controller.bluetoothDeviceTitle(device)
                subtitle: popover.controller.bluetoothAvailableSubtitle(device)
                actionText: busyState ? "Working" : (device && (device.paired || device.bonded) ? "Connect" : "Pair")
                enabled: visible && !busyState
                onClicked: {
                  if (busyState)
                    return;
                  if (device.paired || device.bonded)
                    device.connect();
                  else
                    device.pair();
                }
              }
            }
          }
        }

        Item {
          anchors.top: parent.top
          width: parent.width
          height: availableDevicesSection.scrollIndicatorHeight

          Rectangle {
            anchors.fill: parent
            color: "transparent"
            opacity: availableDevicesSection.scanListHasMoreAbove ? 1 : 0
            gradient: Gradient {
              GradientStop {
                position: 0.0
                color: popover.controller.withAlpha(Theme.submenu, 1)
              }
              GradientStop {
                position: 1.0
                color: popover.controller.withAlpha(Theme.submenu, 0)
              }
            }
          }

          UiIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: Theme.iconGlyphSm
            height: Theme.iconGlyphSm
            name: "chevron-up"
            strokeColor: Theme.textSubtle
            opacity: availableDevicesSection.scanListHasMoreAbove ? 0.8 : 0
          }
        }

        Item {
          anchors.bottom: parent.bottom
          width: parent.width
          height: availableDevicesSection.scrollIndicatorHeight

          Rectangle {
            anchors.fill: parent
            color: "transparent"
            opacity: availableDevicesSection.scanListHasMoreBelow ? 1 : 0
            gradient: Gradient {
              GradientStop {
                position: 0.0
                color: popover.controller.withAlpha(Theme.submenu, 0)
              }
              GradientStop {
                position: 1.0
                color: popover.controller.withAlpha(Theme.submenu, 1)
              }
            }
          }

          UiIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: Theme.iconGlyphSm
            height: Theme.iconGlyphSm
            name: "chevron-down"
            strokeColor: Theme.textSubtle
            opacity: availableDevicesSection.scanListHasMoreBelow ? 0.8 : 0
          }
        }
      }
    }

    Column {
      width: parent.width
      spacing: 4

      Controls.Divider {}

      Controls.PopoverMenuAction {
        width: parent.width
        title: popover.controller.bluetoothPrimaryActionText()
        enabled: !!popover.bluetoothService.adapter && !popover.bluetoothService.busy && (!popover.bluetoothService.blocked || popover.bluetoothService.unblockAvailable)
        onClicked: popover.controller.toggleBluetoothEnabled()
      }

      Controls.PopoverMenuAction {
        width: parent.width
        title: popover.bluetoothService.discovering ? "Stop Scan" : "Scan"
        enabled: !!popover.bluetoothService.adapter && popover.bluetoothService.enabled && !popover.bluetoothService.busy
        onClicked: {
          popover.bluetoothService.setDiscoveryEnabled(!popover.bluetoothService.discovering);
        }
      }
    }
  }
}
