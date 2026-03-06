pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QtControls
import "theme"
import "ui/primitives"
import "ui/controls" as Controls
import "ui/patterns" as Patterns

FocusScope {
  id: root

  signal closeRequested()

  property bool wifiEnabled: true
  property bool bluetoothEnabled: false
  property bool doNotDisturb: true
  property real mediaLevel: 0.68
  property real brightnessLevel: 82
  property real keyboardLevel: 2
  readonly property var surfaceTones: ["panel", "panelOverlay", "raised", "submenu", "field", "fieldAlt", "toggleOff", "toggleOn", "accent", "chip"]

  implicitWidth: 1040
  implicitHeight: 780
  focus: true

  Keys.onEscapePressed: root.closeRequested()

  component GallerySection: UiSurface {
    id: section

    property string title: ""
    property string description: ""
    default property alias content: body.data

    width: parent ? parent.width : implicitWidth
    implicitWidth: 1
    implicitHeight: container.implicitHeight + 24
    tone: "panelOverlay"
    outlined: false
    radius: Theme.radiusLg

    border.width: 1
    border.color: Theme.border

    Column {
      id: container

      width: parent.width - 24
      anchors.left: parent.left
      anchors.leftMargin: 12
      anchors.top: parent.top
      anchors.topMargin: 12
      spacing: 14

      Column {
        width: parent.width
        spacing: 4

        UiText {
          text: section.title
          size: "sm"
          font.weight: Font.DemiBold
        }

        UiText {
          width: parent.width
          visible: text !== ""
          text: section.description
          size: "xs"
          tone: "muted"
          wrapMode: Text.WordWrap
        }
      }

      Column {
        id: body

        width: parent.width
        spacing: 12
      }
    }
  }

  UiSurface {
    id: panel

    width: parent ? Math.max(360, Math.min(parent.width - 48, 1040)) : implicitWidth
    height: parent ? Math.max(420, Math.min(parent.height - 48, 780)) : implicitHeight
    anchors.centerIn: parent
    tone: "panel"
    outlined: false
    radius: Theme.radiusLg
    clip: true

    border.width: 1
    border.color: Theme.border

    Column {
      anchors.fill: parent
      spacing: 0

      UiSurface {
        width: parent.width
        implicitHeight: 84
        tone: "raised"
        radius: 0
        outlined: false

        border.width: 0

        Row {
          anchors.fill: parent
          anchors.leftMargin: 20
          anchors.rightMargin: 20
          spacing: 14

          Column {
            width: Math.max(0, parent.width - themeRow.implicitWidth - closeButton.implicitWidth - 32)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            UiText {
              text: "Widget Gallery"
              size: "lg"
              font.weight: Font.DemiBold
            }

            UiText {
              width: parent.width
              text: "Live preview surface for the extracted Quickshell controls, patterns, and theme tokens."
              size: "xs"
              tone: "muted"
              wrapMode: Text.WordWrap
            }
          }

          Row {
            id: themeRow

            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Repeater {
              model: Theme.themeNames

              delegate: Controls.Button {
                required property var modelData

                text: String(modelData)
                compact: true
                active: Theme.current === String(modelData)
                onClicked: Theme.setTheme(String(modelData))
              }
            }
          }

          Controls.Button {
            id: closeButton

            anchors.verticalCenter: parent.verticalCenter
            text: "Close"
            onClicked: root.closeRequested()
          }
        }
      }

      Flickable {
        id: viewport

        width: parent.width
        height: parent.height - 84
        clip: true
        contentWidth: width
        contentHeight: galleryColumn.implicitHeight + 28
        boundsBehavior: Flickable.StopAtBounds

        QtControls.ScrollBar.vertical: QtControls.ScrollBar {
          policy: QtControls.ScrollBar.AsNeeded
        }

        Column {
          id: galleryColumn

          width: viewport.width - 28
          anchors.left: parent.left
          anchors.leftMargin: 14
          anchors.top: parent.top
          anchors.topMargin: 14
          spacing: 14

          GallerySection {
            title: "Foundations"
            description: "Theme tones, iconography, and typography primitives that the rest of the widget library builds on."

            Flow {
              id: toneFlow

              width: parent.width
              spacing: 10

              Repeater {
                model: root.surfaceTones

                delegate: Item {
                  id: toneSwatch

                  required property var modelData

                  width: 120
                  height: 88

                  UiSurface {
                    width: parent.width
                    height: 58
                    tone: String(toneSwatch.modelData)
                    radius: 16
                    outlined: false
                  }

                  UiText {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    text: String(toneSwatch.modelData)
                    size: "xs"
                    tone: "muted"
                  }
                }
              }
            }

            Row {
              spacing: 14

              Repeater {
                model: ["wifi", "bluetooth", "gauge", "keyboard", "speaker", "power", "check"]

                delegate: Column {
                  id: iconSample

                  required property var modelData

                  spacing: 6

                  UiSurface {
                    width: 52
                    height: 52
                    tone: "fieldAlt"
                    radius: 18
                    outlined: false

                    UiIcon {
                      anchors.centerIn: parent
                        name: String(iconSample.modelData)
                      strokeColor: Theme.iconSecondary
                    }
                  }

                  UiText {
                    width: 52
                    horizontalAlignment: Text.AlignHCenter
                    text: String(iconSample.modelData)
                    size: "xs"
                    tone: "muted"
                  }
                }
              }
            }

            Column {
              spacing: 4

              UiText {
                text: "Large Heading"
                size: "xl"
                font.weight: Font.DemiBold
              }

              UiText {
                text: "Medium body copy for labels and section summaries."
                size: "md"
              }

              UiText {
                text: "Muted annotation text for metadata and helper copy."
                size: "xs"
                tone: "muted"
              }
            }
          }

          GallerySection {
            title: "Buttons"
            description: "Default, accent, active, compact, and disabled states for the shared button control."

            Flow {
              width: parent.width
              spacing: 10

              Controls.Button { text: "Default" }
              Controls.Button { text: "Accent"; variant: "accent" }
              Controls.Button { text: "Active"; active: true }
              Controls.Button { text: "Compact"; compact: true }
              Controls.Button { text: "Disabled"; enabled: false }
            }
          }

          GallerySection {
            title: "Icon Buttons"
            description: "Square, circular, active, disabled, and passive icon-only affordances."

            Flow {
              width: parent.width
              spacing: 10

              Controls.IconButton { iconName: "speaker" }
              Controls.IconButton { iconName: "speaker-muted"; active: true }
              Controls.IconButton { iconName: "power"; circular: true }
              Controls.IconButton { iconName: "lock"; circular: true; active: true }
              Controls.IconButton { iconName: "sun"; interactive: false }
              Controls.IconButton { iconName: "bluetooth"; enabled: false }
            }
          }

          GallerySection {
            title: "Toggles"
            description: "Boolean controls with optional description text and icon treatment."

            Column {
              width: parent.width
              spacing: 10

              Controls.Toggle {
                width: parent.width
                text: "Wi-Fi"
                description: root.wifiEnabled ? "Connected to Studio 5G" : "Radio disabled"
                iconName: "wifi"
                checked: root.wifiEnabled
                onToggled: function(checked) {
                  root.wifiEnabled = checked;
                }
              }

              Controls.Toggle {
                width: parent.width
                text: "Bluetooth"
                description: root.bluetoothEnabled ? "2 devices available" : "Hidden from nearby devices"
                iconName: "bluetooth"
                checked: root.bluetoothEnabled
                onToggled: function(checked) {
                  root.bluetoothEnabled = checked;
                }
              }

              Controls.Toggle {
                width: parent.width
                text: "Do Not Disturb"
                description: "Silence banners and sounds until tomorrow morning"
                iconName: "moon"
                checked: root.doNotDisturb
                onToggled: function(checked) {
                  root.doNotDisturb = checked;
                }
              }
            }
          }

          GallerySection {
            title: "Sliders"
            description: "Continuous controls for volume, brightness, and stepped values."

            Column {
              width: parent.width
              spacing: 12

              Controls.Slider {
                width: parent.width
                iconName: root.mediaLevel <= 0.01 ? "speaker-muted" : "speaker"
                showIcon: true
                value: root.mediaLevel
                showValueText: true
                valueText: `${Math.round(root.mediaLevel * 100)}%`
                onValueMoved: function(value) {
                  root.mediaLevel = value;
                }
                onValueCommitted: function(value) {
                  root.mediaLevel = value;
                }
              }

              Controls.Slider {
                width: parent.width
                iconName: "sun"
                showIcon: true
                from: 0
                to: 100
                value: root.brightnessLevel
                showValueText: true
                valueText: `${Math.round(root.brightnessLevel)}%`
                onValueMoved: function(value) {
                  root.brightnessLevel = value;
                }
                onValueCommitted: function(value) {
                  root.brightnessLevel = value;
                }
              }

              Controls.Slider {
                width: parent.width
                iconName: "keyboard"
                from: 0
                to: 3
                stepSize: 1
                value: root.keyboardLevel
                showValueText: true
                valueText: ["Off", "Low", "Med", "High"][Math.round(root.keyboardLevel)]
                onValueMoved: function(value) {
                  root.keyboardLevel = value;
                }
                onValueCommitted: function(value) {
                  root.keyboardLevel = value;
                }
              }
            }
          }

          GallerySection {
            title: "Menus"
            description: "Static list surfaces for selections, actions, and small popover menus."

            Row {
              width: parent.width
              spacing: 14

              Controls.Menu {
                width: Math.max(220, Math.floor((parent.width - parent.spacing) / 2))

                Controls.MenuItem {
                  width: parent.width
                  iconName: "speaker"
                  title: "Laptop Speakers"
                  subtitle: "Built-in audio"
                  trailingIconName: "check"
                  active: true
                  dividerVisible: true
                }

                Controls.MenuItem {
                  width: parent.width
                  iconName: "speaker"
                  title: "Studio Display"
                  subtitle: "HDMI output"
                  actionText: "Connect"
                  dividerVisible: true
                }

                Controls.MenuItem {
                  width: parent.width
                  iconName: "speaker"
                  title: "USB DAC"
                  subtitle: "Desk setup"
                }
              }

              Controls.Menu {
                width: Math.max(220, Math.floor((parent.width - parent.spacing) / 2))

                Controls.MenuItem {
                  width: parent.width
                  iconName: "power"
                  title: "Power Off"
                  compact: true
                  dividerVisible: true
                }

                Controls.MenuItem {
                  width: parent.width
                  iconName: "restart"
                  title: "Restart"
                  compact: true
                  dividerVisible: true
                  active: true
                }

                Controls.MenuItem {
                  width: parent.width
                  iconName: "logout"
                  title: "Log Out"
                  compact: true
                }
              }
            }
          }

          GallerySection {
            title: "Quick Tiles"
            description: "Split-action patterns for dashboard toggles and compact status affordances."

            Flow {
              id: quickTileFlow

              width: parent.width
              spacing: 10

              Patterns.QuickTile {
                width: Math.max(220, Math.floor((parent.width - quickTileFlow.spacing) / 2))
                iconName: "wifi"
                title: root.wifiEnabled ? "Studio 5G" : "Wi-Fi"
                subtitle: root.wifiEnabled ? "78%" : "Off"
                active: root.wifiEnabled
                expanded: root.wifiEnabled
                highlightExpanded: true
                onPrimaryClicked: root.wifiEnabled = !root.wifiEnabled
              }

              Patterns.QuickTile {
                width: Math.max(220, Math.floor((parent.width - quickTileFlow.spacing) / 2))
                iconName: "bluetooth"
                title: root.bluetoothEnabled ? "2 Devices" : "Bluetooth"
                subtitle: root.bluetoothEnabled ? "Ready" : "Off"
                active: root.bluetoothEnabled
                onPrimaryClicked: root.bluetoothEnabled = !root.bluetoothEnabled
              }

              Patterns.QuickTile {
                width: Math.max(220, Math.floor((parent.width - quickTileFlow.spacing) / 2))
                iconName: "gauge"
                title: "Performance"
                subtitle: "Power Mode"
                expanded: true
                highlightExpanded: true
              }

              Patterns.QuickTile {
                width: Math.max(220, Math.floor((parent.width - quickTileFlow.spacing) / 2))
                iconName: "keyboard"
                title: ["Off", "Low", "Med", "High"][Math.round(root.keyboardLevel)]
                subtitle: "Keyboard Light"
                active: Math.round(root.keyboardLevel) > 0
                expandable: false
                onPrimaryClicked: root.keyboardLevel = (Math.round(root.keyboardLevel) + 1) % 4
              }
            }
          }
        }
      }
    }
  }
}
