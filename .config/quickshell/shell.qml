import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland


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

    Rectangle {
      anchors.fill: parent
      color: "#80000000"

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

    Rectangle {
      anchors.fill: parent
      radius: 24
      color: "#202020"

      Text {
        anchors.centerIn: parent
        text: "Shade (placeholder) - next: battery/perf/volume/brightness/etc."
        color: "white"
        font.pixelSize: 22
      }
    }
  }

}
