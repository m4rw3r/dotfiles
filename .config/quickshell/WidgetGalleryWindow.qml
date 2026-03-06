pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "ui/primitives"

PanelWindow {
  id: root

  property bool galleryOpen: false
  signal closeRequested()

  visible: galleryOpen
  anchors { left: true; right: true; top: true; bottom: true }
  exclusionMode: ExclusionMode.Ignore
  aboveWindows: true
  color: "transparent"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

  onVisibleChanged: {
    if (visible) gallery.forceActiveFocus();
  }

  UiScrim {
    anchors.fill: parent

    MouseArea {
      anchors.fill: parent
      onClicked: root.closeRequested()
    }
  }

  WidgetGallery {
    id: gallery

    anchors.centerIn: parent
    onCloseRequested: root.closeRequested()
  }
}
