pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "theme"
import "ui/primitives"

FocusScope {
  id: root

  property string mode: "peek"
  property bool controlCenterOpen: false
  property bool forcedVisible: false
  property bool showPassive: false
  property var panelWindow: null
  readonly property bool expanded: mode === "expanded"
  // qmllint disable missing-property
  readonly property bool hasAnyItems: trayItems.count > 0
  // qmllint enable missing-property
  readonly property int urgentCount: countItems(Status.NeedsAttention)
  readonly property int activeCount: countItems(Status.Active)
  readonly property int passiveCount: countItems(Status.Passive)
  readonly property bool hasAttention: urgentCount > 0
  readonly property bool showPlaceholder: !hasAnyItems || (forcedVisible && !hasAttention && !expanded)
  property real offsetX: 0

  signal dismissRequested()
  signal expandRequested()

  implicitWidth: railSurface.implicitWidth
  implicitHeight: railSurface.implicitHeight

  Keys.onEscapePressed: {
    if (expanded) dismissRequested();
  }

  function countItems(status) {
    let count = 0;
    // qmllint disable missing-property
    for (let i = 0; i < SystemTray.items.count; i += 1) {
      const item = SystemTray.items.get(i);
      if (item && item.status === status) count += 1;
    }
    // qmllint enable missing-property
    return count;
  }

  function openMenu(item, target) {
    if (!item || !item.hasMenu || !panelWindow || !target) return;
    const point = target.mapToItem(null, target.width, Math.round(target.height / 2));
    item.display(panelWindow, Math.round(point.x), Math.round(point.y));
  }

  function triggerIntro() {
    offsetX = controlCenterOpen ? 12 : 18;
    root.opacity = 0;
    introAnimation.restart();
  }

  Component.onCompleted: triggerIntro()

  Instantiator {
    id: trayItems

    model: SystemTray.items

    delegate: Item {
      required property var modelData
      visible: false
      width: 0
      height: 0
    }
  }

  onModeChanged: {
    if (!expanded) showPassive = false;
    triggerIntro();
  }

  onControlCenterOpenChanged: triggerIntro()

  Connections {
    target: root.panelWindow
    ignoreUnknownSignals: true

    function onVisibleChanged() {
      if (root.panelWindow && root.panelWindow.visible) root.triggerIntro();
    }
  }

  ParallelAnimation {
    id: introAnimation

    NumberAnimation {
      target: root
      property: "offsetX"
      to: 0
      duration: Theme.motionBase
      easing.type: Easing.OutCubic
    }

    NumberAnimation {
      target: root
      property: "opacity"
      to: 1
      duration: Theme.motionFast
      easing.type: Easing.OutCubic
    }
  }

  transform: Translate {
    x: root.offsetX
  }

  component TrayItemButton: UiSurface {
    id: button

    required property var item
    required property bool attention
    required property bool peekButton
    property bool placeholder: false
    property bool holdTriggered: false
    property string iconName: ""
    readonly property bool showSecondaryArea: root.expanded && !button.placeholder && !button.peekButton && !!button.item && button.item.hasMenu
    readonly property int secondaryWidth: showSecondaryArea ? 28 : 0
    readonly property bool useTrayImage: !button.placeholder && button.iconName === "" && !!button.item

    signal primaryTriggered()
    signal secondaryTriggered()

    width: railColumn.width
    height: Theme.controlMd + Theme.gapXs
    radius: Theme.radiusMd
    tone: attention ? "accent" : "field"
    outlined: false
    pressed: primaryTouch.pressed || secondaryTouch.pressed
    opacity: item || placeholder ? 1 : 0.5
    border.width: Theme.stroke
    border.color: attention ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)

    color: {
      if (attention) return pressed ? Theme.accentStrong : Theme.accent;
      return pressed ? Theme.fieldPressed : Theme.field;
    }

    function triggerPrimary(buttonCode) {
      if (button.peekButton) {
        root.expandRequested();
        return;
      }

      if (button.placeholder || !button.item) {
        button.primaryTriggered();
        return;
      }

      if (buttonCode === Qt.RightButton && button.item.hasMenu) {
        root.openMenu(button.item, button.showSecondaryArea ? secondarySlot : button);
        return;
      }

      if (button.item.onlyMenu) {
        if (button.item.hasMenu) root.openMenu(button.item, button.showSecondaryArea ? secondarySlot : button);
        return;
      }

      button.item.activate();
    }

    function triggerSecondary() {
      if (button.placeholder || !button.item) {
        button.secondaryTriggered();
        return;
      }

      if (button.item.hasMenu) {
        root.openMenu(button.item, secondarySlot);
        return;
      }

      if (!button.item.onlyMenu) button.item.activate();
    }

    Rectangle {
      visible: button.showSecondaryArea
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      width: button.secondaryWidth
      radius: Theme.radiusMd
      color: secondaryTouch.pressed
        ? (button.attention ? Theme.accentStrong : Theme.fieldAlt)
        : "transparent"
    }

    Rectangle {
      visible: button.showSecondaryArea
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      anchors.rightMargin: button.secondaryWidth
      width: Theme.stroke
      color: button.attention ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
    }

    Item {
      id: primarySlot

      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.rightMargin: button.secondaryWidth
    }

    Item {
      id: secondarySlot

      visible: button.showSecondaryArea
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      width: button.secondaryWidth
    }

    UiIcon {
      visible: !button.useTrayImage
      anchors.centerIn: primarySlot
      width: Theme.iconGlyphMd
      height: Theme.iconGlyphMd
      name: button.iconName !== ""
        ? button.iconName
        : (button.placeholder ? (root.expanded ? "panel-right-open" : "panel-right") : String(button.item.icon || "panel-right"))
      strokeColor: button.attention ? Theme.textOnAccent : Theme.text
    }

    IconImage {
      visible: button.useTrayImage
      anchors.centerIn: primarySlot
      implicitSize: Theme.iconGlyphMd
      asynchronous: true
      mipmap: true
      source: button.item && button.item.icon !== "" ? String(button.item.icon) : "image://icon/application-x-executable"
    }

    UiIcon {
      visible: button.showSecondaryArea
      anchors.centerIn: secondarySlot
      width: Theme.iconGlyphSm
      height: Theme.iconGlyphSm
      name: "more-horizontal"
      strokeColor: button.attention ? Theme.textOnAccent : Theme.textMuted
    }

    Rectangle {
      visible: button.attention
      width: 10
      height: 10
      radius: 5
      color: Theme.textOnAccent
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: Theme.nudge
      anchors.rightMargin: Theme.nudge
    }

    MouseArea {
      id: primaryTouch

      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.rightMargin: button.secondaryWidth
      enabled: button.placeholder || !!button.item
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      pressAndHoldInterval: 300

      onPressed: mouse => {
        button.holdTriggered = false;
        if (!button.item || button.peekButton) return;
        if (mouse.button === Qt.RightButton && button.item.hasMenu) {
          button.holdTriggered = true;
          root.openMenu(button.item, button.showSecondaryArea ? secondarySlot : button);
          mouse.accepted = true;
        }
      }

      onPressAndHold: {
        if (!button.item || button.peekButton || !button.item.hasMenu) return;
        button.holdTriggered = true;
        root.openMenu(button.item, button.showSecondaryArea ? secondarySlot : button);
      }

      onClicked: mouse => {
        if (button.holdTriggered) return;
        button.triggerPrimary(mouse.button);
      }
    }

    MouseArea {
      id: secondaryTouch

      visible: button.showSecondaryArea
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      width: button.secondaryWidth
      enabled: button.showSecondaryArea
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onPressed: mouse => {
        if (mouse.button === Qt.RightButton) {
          button.holdTriggered = true;
          button.triggerSecondary();
          mouse.accepted = true;
          return;
        }

        button.holdTriggered = false;
      }
      onClicked: {
        if (button.holdTriggered) return;
        button.triggerSecondary();
      }
    }
  }

  UiSurface {
    id: railSurface

    width: implicitWidth
    implicitWidth: root.expanded ? 104 : 60
    implicitHeight: railColumn.implicitHeight + Theme.insetSm * 2
    tone: "panelOverlay"
    outlined: false
    radius: Theme.radiusLg
    border.width: Theme.stroke
    border.color: Qt.rgba(1, 1, 1, 0.12)

    Column {
      id: railColumn

      width: parent.width - Theme.insetSm * 2
      anchors.top: parent.top
      anchors.topMargin: Theme.insetSm
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Theme.gapXs

      TrayItemButton {
        visible: root.showPlaceholder && !root.expanded
        item: null
        attention: root.hasAttention
        peekButton: !root.expanded
        placeholder: true
      }

      TrayItemButton {
        visible: root.expanded
        item: null
        attention: false
        peekButton: false
        placeholder: true
        iconName: "x"
        onPrimaryTriggered: root.dismissRequested()
      }

      Rectangle {
        visible: root.expanded && (root.hasAnyItems || root.passiveCount > 0)
        width: parent.width
        height: 1
        color: Theme.divider
        opacity: 0.55
      }

      Repeater {
        model: SystemTray.items

        delegate: TrayItemButton {
          required property var modelData

          visible: modelData && modelData.status === Status.NeedsAttention
          item: modelData
          attention: true
          peekButton: !root.expanded
        }
      }

      Rectangle {
        visible: root.expanded && root.urgentCount > 0 && root.activeCount > 0
        width: parent.width
        height: 1
        color: Theme.divider
        opacity: 0.55
      }

      Repeater {
        model: SystemTray.items

        delegate: TrayItemButton {
          required property var modelData

          visible: root.expanded && modelData && modelData.status === Status.Active
          item: modelData
          attention: false
          peekButton: false
        }
      }

      Rectangle {
        visible: root.expanded && root.passiveCount > 0
        width: parent.width
        height: 1
        color: Theme.divider
        opacity: 0.55
      }

      TrayItemButton {
        visible: root.expanded && root.passiveCount > 0
        item: null
        attention: false
        peekButton: false
        placeholder: true
        iconName: root.showPassive ? "chevron-up" : "more-horizontal"
        onPrimaryTriggered: root.showPassive = !root.showPassive
      }

      Repeater {
        model: SystemTray.items

        delegate: TrayItemButton {
          required property var modelData

          visible: root.expanded && root.showPassive && modelData && modelData.status === Status.Passive
          item: modelData
          attention: false
          peekButton: false
        }
      }

      UiText {
        visible: root.expanded && !root.hasAnyItems
        width: parent.width
        text: "No tray\nitems"
        size: "xs"
        tone: "subtle"
        horizontalAlignment: Text.AlignHCenter
      }

    }
  }
}
