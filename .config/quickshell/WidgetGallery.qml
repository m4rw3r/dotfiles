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
  property bool galleryProfilePopoverOpen: false
  property bool galleryWifiMenuOpen: false
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
    implicitHeight: container.implicitHeight + Theme.insetLg
    tone: "panelOverlay"
    outlined: false
    radius: Theme.radiusLg

    border.width: Theme.stroke
    border.color: Theme.border

    Column {
      id: container

      width: parent.width - Theme.insetLg
      anchors.left: parent.left
      anchors.leftMargin: Theme.insetSm
      anchors.top: parent.top
      anchors.topMargin: Theme.insetSm
      spacing: Theme.gapMd

      Column {
        width: parent.width
        spacing: Theme.nudge

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
        spacing: Theme.gapSm
      }
    }
  }

  component PopoverSurface: UiSurface {
    id: popover

    default property alias content: popoverColumn.data
    property int horizontalPadding: Theme.insetSm
    property int verticalPadding: Theme.insetSm

    width: implicitWidth
    height: implicitHeight
    implicitWidth: Theme.popoverWidthSm
    implicitHeight: popoverColumn.implicitHeight + verticalPadding * 2
    tone: "submenu"
    outlined: false
    radius: Theme.radiusMd
    clip: true

    border.width: Theme.stroke
    border.color: Qt.rgba(1, 1, 1, 0.08)

    Column {
      id: popoverColumn

      width: parent.width - popover.horizontalPadding * 2
      anchors.left: parent.left
      anchors.leftMargin: popover.horizontalPadding
      anchors.top: parent.top
      anchors.topMargin: popover.verticalPadding
      spacing: Theme.nudge
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
        implicitHeight: Theme.controlMd * 2
        tone: "raised"
        radius: 0
        outlined: false

        border.width: 0

        Row {
          anchors.fill: parent
          anchors.leftMargin: Theme.gapMd
          anchors.rightMargin: Theme.gapMd
          spacing: Theme.gapMd

          Column {
            width: Math.max(0, parent.width - themeRow.implicitWidth - closeButton.implicitWidth - Theme.controlSm)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.nudge

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
        height: parent.height - Theme.controlMd * 2
        clip: true
        contentWidth: width
        contentHeight: galleryColumn.implicitHeight + Theme.gapLg + Theme.nudge
        boundsBehavior: Flickable.StopAtBounds

        QtControls.ScrollBar.vertical: QtControls.ScrollBar {
          policy: QtControls.ScrollBar.AsNeeded
        }

        Column {
          id: galleryColumn

          width: viewport.width - Theme.gapLg - Theme.nudge
          anchors.left: parent.left
          anchors.leftMargin: Theme.gapMd
          anchors.top: parent.top
          anchors.topMargin: Theme.gapMd
          spacing: Theme.gapMd

          GallerySection {
            title: "Foundations"
            description: "Theme tones, iconography, and typography primitives that the rest of the widget library builds on."

            Flow {
              id: toneFlow

              width: parent.width
              spacing: Theme.gapXs

              Repeater {
                model: root.surfaceTones

                delegate: Item {
                  id: toneSwatch

                  required property var modelData

                  width: Theme.controlMd * 2 + Theme.gapLg + Theme.gapXs
                  height: Theme.controlMd * 2

                  UiSurface {
                    width: parent.width
                    height: Theme.controlMd + Theme.gapSm
                    tone: String(toneSwatch.modelData)
                    radius: Theme.radiusMd
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
              spacing: Theme.gapMd

              Repeater {
                model: ["wifi", "bluetooth", "gauge", "keyboard", "speaker", "power", "check"]

                delegate: Column {
                  id: iconSample

                  required property var modelData

                  spacing: Theme.gapXs

                  UiSurface {
                    width: Theme.controlMd + Theme.gapXs
                    height: Theme.controlMd + Theme.gapXs
                    tone: "fieldAlt"
                    radius: Theme.radiusMd
                    outlined: false

                    UiIcon {
                      anchors.centerIn: parent
                        name: String(iconSample.modelData)
                      strokeColor: Theme.iconSecondary
                    }
                  }

                  UiText {
                    width: Theme.controlMd + Theme.gapXs
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
              spacing: Theme.gapXs

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
              spacing: Theme.gapXs

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
              spacing: Theme.gapXs

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
              spacing: Theme.gapMd

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

            Row {
              width: parent.width
              spacing: Theme.gapMd

              UiSurface {
                id: popoverPreview

                width: Math.max(240, Math.floor((parent.width - parent.spacing) / 2))
                implicitHeight: popoverPreviewProfileTile.implicitHeight + 36
                tone: "panel"
                outlined: false
                radius: Theme.radiusLg

                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)

                UiScrim {
                  anchors.fill: parent
                  radius: popoverPreview.radius
                  visible: root.galleryProfilePopoverOpen
                }

                MouseArea {
                  anchors.fill: parent
                  enabled: root.galleryProfilePopoverOpen
                  onClicked: root.galleryProfilePopoverOpen = false
                }

                Patterns.QuickSelectorTile {
                  id: popoverPreviewProfileTile

                  width: parent.width - Theme.controlSm
                  anchors.left: parent.left
                  anchors.leftMargin: Theme.gapMd
                  anchors.bottom: parent.bottom
                  anchors.bottomMargin: Theme.gapMd
                  iconName: "gauge"
                  title: "Saver"
                  useActiveStyling: false
                  open: root.galleryProfilePopoverOpen
                  onClicked: root.galleryProfilePopoverOpen = !root.galleryProfilePopoverOpen
                }

                PopoverSurface {
                  visible: root.galleryProfilePopoverOpen
                  width: implicitWidth
                  x: popoverPreviewProfileTile.x
                  y: popoverPreviewProfileTile.y + (popoverPreviewProfileTile.height - height) / 2
                  z: 2

                  Controls.MenuItem {
                    width: parent.width
                    iconName: "gauge"
                    title: "Performance"
                    compact: true
                    dividerVisible: true
                  }

                  Controls.MenuItem {
                    width: parent.width
                    iconName: "gauge"
                    title: "Balanced"
                    compact: true
                    dividerVisible: true
                  }

                  Controls.MenuItem {
                    width: parent.width
                    iconName: "gauge"
                    title: "Power Saver"
                    trailingIconName: "check"
                    active: true
                    activeStyle: "indicator"
                    compact: true
                  }
                }
              }

              UiSurface {
                id: menuPreview

                width: Math.max(240, Math.floor((parent.width - parent.spacing) / 2))
                implicitHeight: menuPreviewSlot.implicitHeight + 36
                tone: "panel"
                outlined: false
                radius: Theme.radiusLg

                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)

                UiScrim {
                  anchors.fill: parent
                  radius: menuPreview.radius
                  visible: root.galleryWifiMenuOpen
                }

                TapHandler {
                  enabled: root.galleryWifiMenuOpen
                  onTapped: function(eventPoint) {
                    const point = eventPoint.position;
                    const x = menuPreviewPanel.x;
                    const y = menuPreviewPanel.y;
                    if (point.x >= x && point.x <= x + menuPreviewPanel.width && point.y >= y && point.y <= y + menuPreviewPanel.height) return;
                    root.galleryWifiMenuOpen = false;
                  }
                }

                Column {
                  id: menuPreviewSlot

                  width: parent.width - Theme.controlSm
                  anchors.left: parent.left
                  anchors.leftMargin: Theme.gapMd
                  anchors.bottom: parent.bottom
                  anchors.bottomMargin: Theme.gapMd
                  spacing: 0

                  Patterns.QuickToggleMenuTile {
                    id: menuPreviewTile

                    visible: !menuPreviewPanel.visible
                    width: parent.width
                    iconName: "wifi"
                    title: root.wifiEnabled ? "Studio 5G" : "Wi-Fi"
                    active: root.wifiEnabled
                    menuOpen: root.galleryWifiMenuOpen
                    onPrimaryClicked: root.wifiEnabled = !root.wifiEnabled
                    onSecondaryClicked: root.galleryWifiMenuOpen = !root.galleryWifiMenuOpen
                  }

                  Patterns.QuickTileMenuPanel {
                    id: menuPreviewPanel

                    visible: root.galleryWifiMenuOpen
                    width: parent.width
                    iconName: "wifi"
                    title: root.wifiEnabled ? "Studio 5G" : "Wi-Fi"

                    Controls.Menu {
                      width: parent.width

                      Controls.MenuItem {
                        width: parent.width
                        iconName: "wifi"
                        title: "Studio 5G"
                        subtitle: "78%, WPA3, saved"
                        trailingIconName: "check"
                        active: true
                        activeStyle: "subtle"
                        dividerVisible: true
                      }

                      Controls.MenuItem {
                        width: parent.width
                        iconName: "wifi"
                        title: "Guest Network"
                        subtitle: "54%, open"
                        actionText: "Connect"
                      }
                    }

                    Row {
                      width: parent.width
                      spacing: 8

                      Controls.Button {
                        text: root.wifiEnabled ? "Turn Off" : "Turn On"
                        onClicked: root.wifiEnabled = !root.wifiEnabled
                      }

                      Controls.Button {
                        text: "Rescan"
                      }
                    }
                  }
                }
              }
            }
          }

          GallerySection {
            title: "Quick Tiles"
            description: "Separate toggle, selector, and toggle-plus-submenu quick-tile patterns."

            Flow {
              id: quickTileFlow

              width: parent.width
              spacing: Theme.gapXs

              Patterns.QuickToggleTile {
                width: Math.max(220, Math.floor((parent.width - quickTileFlow.spacing) / 2))
                iconName: "moon"
                title: "Do Not Disturb"
                active: root.doNotDisturb
                onClicked: root.doNotDisturb = !root.doNotDisturb
              }

              Patterns.QuickToggleMenuTile {
                width: Math.max(220, Math.floor((parent.width - quickTileFlow.spacing) / 2))
                iconName: "wifi"
                title: root.wifiEnabled ? "Studio 5G" : "Wi-Fi"
                active: root.wifiEnabled
                menuOpen: root.galleryWifiMenuOpen
                onPrimaryClicked: root.wifiEnabled = !root.wifiEnabled
                onSecondaryClicked: root.galleryWifiMenuOpen = !root.galleryWifiMenuOpen
              }

              Patterns.QuickSelectorTile {
                width: Math.max(220, Math.floor((parent.width - quickTileFlow.spacing) / 2))
                iconName: "gauge"
                title: "Balanced"
                useActiveStyling: false
              }

              Patterns.QuickSelectorTile {
                width: Math.max(220, Math.floor((parent.width - quickTileFlow.spacing) / 2))
                iconName: "keyboard"
                title: ["Off", "Low", "Med", "High"][Math.round(root.keyboardLevel)]
                active: Math.round(root.keyboardLevel) > 0
                useActiveStyling: true
              }
            }
          }
        }
      }
    }
  }
}
