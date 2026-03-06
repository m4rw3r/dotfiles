import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "theme"
import "ui/primitives"

ShellRoot {
  id: root

  property bool shadeOpen: false

  IpcHandler {
    target: "ui"
    function toggleShade() {
      shadeOpen = !shadeOpen;
      if (shadeOpen) launcher.closeLauncher();
    }
    function openShade() {
      shadeOpen = true;
      launcher.closeLauncher();
    }
    function closeShade() {
      shadeOpen = false;
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
    onLauncherOpening: root.shadeOpen = false
  }

  PanelWindow {
    visible: shadeOpen
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay

    UiScrim {
      anchors.fill: parent

      MouseArea {
        anchors.fill: parent
        onClicked: shadeOpen = false
      }
    }
  }

  PanelWindow {
    visible: shadeOpen
    anchors { left: true; right: true; top: true }
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    implicitHeight: 420
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top

    ControlCenter {
      anchors.fill: parent
    }
  }

}
