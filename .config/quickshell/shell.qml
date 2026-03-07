pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "theme"
import "ui/primitives"

ShellRoot {
  id: root

  property bool shadeOpen: false
  property bool galleryOpen: false

  IpcHandler {
    target: "ui"
    function toggleShade() {
      root.shadeOpen = !root.shadeOpen;
      if (root.shadeOpen) root.galleryOpen = false;
      if (root.shadeOpen) launcher.closeLauncher();
    }
    function openShade() {
      root.shadeOpen = true;
      root.galleryOpen = false;
      launcher.closeLauncher();
    }
    function closeShade() {
      root.shadeOpen = false;
    }
  }

  IpcHandler {
    target: "gallery"

    function toggle() {
      root.galleryOpen = !root.galleryOpen;
      if (root.galleryOpen) {
        root.shadeOpen = false;
        launcher.closeLauncher();
      }
    }

    function open() {
      root.galleryOpen = true;
      root.shadeOpen = false;
      launcher.closeLauncher();
    }

    function close() {
      root.galleryOpen = false;
    }
  }

  IpcHandler {
    target: "theme"

    function current() {
      return Theme.current;
    }

    function list() {
      return Theme.themeNames;
    }

    function set(name: string): void {
      Theme.setTheme(String(name));
    }

    function toggle() {
      return Theme.toggleTheme();
    }
  }

  Launcher {
    id: launcher
    onLauncherOpening: {
      root.shadeOpen = false;
      root.galleryOpen = false;
    }
  }

  PanelWindow {
    visible: root.shadeOpen
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    UiScrim {
      anchors.fill: parent

      MouseArea {
        anchors.fill: parent
        onClicked: root.shadeOpen = false
      }
    }
  }

  PanelWindow {
    visible: root.shadeOpen
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    onVisibleChanged: {
      if (visible) controlCenter.forceActiveFocus();
    }

    MouseArea {
      anchors.fill: parent
      onClicked: {
        if (controlCenter.overlayDismissActive) controlCenter.dismissOverlaySection();
        else root.shadeOpen = false;
      }
    }

    ControlCenter {
      id: controlCenter

      panelOpen: root.shadeOpen
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: 14
      anchors.rightMargin: 14

      onCloseRequested: root.shadeOpen = false
    }
  }

  WidgetGalleryWindow {
    galleryOpen: root.galleryOpen
    onCloseRequested: root.galleryOpen = false
  }

}
