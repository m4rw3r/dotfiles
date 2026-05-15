pragma ComponentBehavior: Bound

import QtQuick
import "../ui/controls" as Controls
import "../ui/patterns" as Patterns

Patterns.HeroSheetPopover {
  id: popover

  required property var controller

  visible: controller ? controller.powerMenuOpen : false
  iconName: controller ? controller.powerActionIcon(controller.powerHeroAction()) : "power"
  title: controller ? controller.powerActionTitle(controller.powerHeroAction()) : "Power Off"
  subtitle: controller ? controller.powerHeroHint() : ""

  Column {
    width: parent.width
    spacing: 4

    Column {
      width: parent.width
      spacing: 2

      Repeater {
        model: popover.controller ? popover.controller.powerMenuEntries : []

        delegate: Item {
          required property var modelData
          readonly property var entry: modelData

          width: parent.width
          height: entry.kind === "divider" ? divider.height : action.implicitHeight

          Controls.Divider {
            id: divider
            visible: parent.entry.kind === "divider"
          }

          Controls.PopoverMenuAction {
            id: action

            visible: parent.entry.kind === "action"
            width: parent.width
            title: parent.entry.title || ""
            actionText: popover.controller && !!parent.entry.confirm && popover.controller.pendingPowerAction === parent.entry.action ? "Confirm" : ""
            active: popover.controller && !!parent.entry.confirm && popover.controller.pendingPowerAction === parent.entry.action
            enabled: popover.controller && !popover.controller.sessionActionBusy
            onClicked: {
              if (!popover.controller)
                return;
              if (parent.entry.confirm)
                popover.controller.triggerPowerAction(parent.entry.action);
              else
                popover.controller.runSessionAction(parent.entry.action);
            }
          }
        }
      }
    }
  }
}
