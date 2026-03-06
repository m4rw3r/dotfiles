pragma ComponentBehavior: Bound

import QtQuick
import "theme"
import "ui/primitives"

Item {
  UiSurface {
    anchors.fill: parent
    tone: "raised"
    outlined: true
    radius: Theme.radiusLg
  }

  Column {
    anchors.fill: parent
    anchors.margins: 28
    spacing: 14

    UiText {
      text: "Quick Controls"
      size: "lg"
      font.weight: Font.DemiBold
    }

    UiText {
      text: "Theme"
      size: "sm"
      tone: "subtle"
      font.weight: Font.DemiBold
    }

    Row {
      spacing: 10

      Repeater {
        model: Theme.themeNames

        delegate: UiSurface {
          id: themeChip

          required property string modelData

          width: Math.max(94, themeName.implicitWidth + 26)
          height: 40
          radius: Theme.radiusSm
          tone: Theme.current === themeChip.modelData ? "accent" : "field"
          outlined: Theme.current !== themeChip.modelData

          UiText {
            id: themeName

            anchors.centerIn: parent
            text: themeChip.modelData
            size: "sm"
            tone: Theme.current === themeChip.modelData ? "onAccent" : "primary"
            font.weight: Font.DemiBold
          }

          MouseArea {
            anchors.fill: parent
            onClicked: Theme.setTheme(themeChip.modelData)
          }
        }
      }
    }

    UiText {
      text: "Current: " + Theme.current
      size: "sm"
      tone: "muted"
    }

    UiText {
      text: "Use IPC: quickshell ipc call theme set <name>"
      size: "sm"
      tone: "subtle"
    }
  }
}
