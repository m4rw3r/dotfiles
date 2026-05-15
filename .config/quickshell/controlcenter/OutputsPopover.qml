pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import "../theme"
import "../ui/primitives"
import "../ui/controls" as Controls
import "../ui/patterns" as Patterns

Patterns.HeroSheetPopover {
  id: popover

  required property var controller

  visible: controller ? controller.outputMenuOpen : false
  iconName: controller && controller.audioReady && controller.audioState.muted ? "speaker-muted" : "speaker"
  title: controller ? controller.outputMenuTitle() : "Sound Output"
  subtitle: controller ? controller.outputMenuSubtitle() : ""
  hasStatus: controller ? controller.audioReady : false
  statusActive: controller ? controller.audioReady && !controller.audioState.muted : false
  statusToggleEnabled: controller ? controller.audioReady : false
  onStatusClicked: {
    if (controller && controller.audioReady)
      controller.audioState.muted = !controller.audioState.muted;
  }

  Column {
    width: parent.width
    spacing: 8

    UiText {
      visible: popover.controller && !popover.controller.audioLoading && !popover.controller.audioReady && Pipewire.ready
      text: popover.controller && popover.controller.audioSink ? "Audio unavailable." : "No audio output available."
      size: "xs"
      tone: "accent"
      wrapMode: Text.WordWrap
    }

    Column {
      width: parent.width
      spacing: 2

      Repeater {
        model: Pipewire.nodes

        delegate: Controls.PopoverMenuAction {
          id: outputRow

          required property var modelData
          readonly property var outputNode: modelData
          readonly property bool shown: !!(outputNode && outputNode.audio && outputNode.isSink && !outputNode.isStream)

          visible: shown
          width: parent.width
          title: popover.controller ? popover.controller.outputLabel(outputRow.outputNode) : ""
          trailingIconName: popover.controller && popover.controller.audioSink === outputRow.outputNode ? "check" : ""
          trailingIconColor: Theme.text
          active: popover.controller && popover.controller.audioSink === outputRow.outputNode
          enabled: shown
          onClicked: Pipewire.preferredDefaultAudioSink = outputRow.outputNode
        }
      }
    }
  }
}
