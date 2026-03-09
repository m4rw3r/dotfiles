import QtQuick
import "../primitives" as Ui
import "../../theme"

Ui.UiSurface {
  id: root

  property string iconName: ""
  property string title: ""
  property string subtitle: ""
  property bool hasStatus: false
  property bool statusActive: false
  property bool statusBusy: false
  property bool statusToggleEnabled: hasStatus
  property int horizontalPadding: Theme.insetSm
  property int verticalPadding: Theme.insetSm
  property int sectionSpacing: Theme.gapSm
  default property alias content: bodyColumn.data
  signal statusClicked()

  readonly property bool statusInteractive: hasStatus && statusToggleEnabled && !statusBusy

  width: implicitWidth
  implicitWidth: 1
  implicitHeight: sheetColumn.implicitHeight + verticalPadding * 2
  tone: "submenu"
  outlined: false
  radius: Theme.radiusMd
  color: Theme.submenu
  z: 8
  clip: true

  border.width: Theme.stroke
  border.color: Qt.rgba(1, 1, 1, 0.08)

  Column {
    id: sheetColumn

    width: parent.width - root.horizontalPadding * 2
    anchors.left: parent.left
    anchors.leftMargin: root.horizontalPadding
    anchors.top: parent.top
    anchors.topMargin: root.verticalPadding
    spacing: root.sectionSpacing

    Row {
      width: parent.width
      spacing: Theme.gapXs

      Rectangle {
        id: heroBadge

        width: Theme.controlMd
        height: Theme.controlMd
        radius: width / 2
        color: {
          if (!root.hasStatus) return Qt.rgba(1, 1, 1, 0.16);
          if (root.statusActive) return heroTouch.pressed ? Theme.toggleOnStrong : Theme.toggleOn;
          if (!root.statusToggleEnabled) return Theme.field;
          return heroTouch.pressed ? Theme.fieldPressed : Theme.toggleOff;
        }
        border.width: root.hasStatus && !root.statusActive ? Theme.stroke : 0
        border.color: Qt.rgba(1, 1, 1, 0.08)

        Ui.UiIcon {
          anchors.centerIn: parent
          width: Theme.iconGlyphMd
          height: Theme.iconGlyphMd
          name: root.iconName
          strokeColor: root.hasStatus && root.statusActive ? Theme.textOnAccent : Theme.text
          stroke: 2.1
        }

        MouseArea {
          id: heroTouch

          anchors.fill: parent
          enabled: root.statusInteractive
          onClicked: root.statusClicked()
        }
      }

      Column {
        width: Math.max(0, parent.width - Theme.controlMd - Theme.gapSm - Theme.nudge)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.nudge

        Ui.UiText {
          width: parent.width
          text: root.title
          size: "lg"
          font.weight: Font.Bold
          elide: Text.ElideRight
        }

        Ui.UiText {
          width: parent.width
          visible: text !== ""
          text: root.subtitle
          size: "xs"
          tone: "subtle"
          wrapMode: Text.WordWrap
        }
      }
    }

    Column {
      id: bodyColumn

      width: parent.width
      spacing: 0
    }
  }
}
