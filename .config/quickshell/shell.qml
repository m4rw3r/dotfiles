pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "theme"
import "ui/controls" as Controls
import "ui/primitives"

ShellRoot {
  id: root

  property bool shadeOpen: false
  property bool galleryOpen: false

  component SessionActionController: Item {
    id: controller

    property string busyAction: ""
    property string failedAction: ""
    property string lastError: ""
    readonly property bool busy: busyAction !== ""
    readonly property bool errorVisible: lastError !== ""
    readonly property bool bannerVisible: busy || errorVisible

    function actionTitle(action) {
      if (action === "lock") return "Lock";
      if (action === "sleep") return "Suspend";
      if (action === "restart") return "Restart";
      if (action === "logout") return "Log Out";
      if (action === "shutdown") return "Power Off";
      return "Session Action";
    }

    function actionIcon(action) {
      if (action === "lock") return "lock";
      if (action === "sleep") return "moon";
      if (action === "restart") return "restart";
      if (action === "logout") return "logout";
      if (action === "shutdown") return "power";
      return "alert-circle";
    }

    function busyTitle() {
      return `${actionTitle(busyAction)} in progress`;
    }

    function busyDescription() {
      if (busyAction === "lock") return "Waiting for the lock screen to take over.";
      return "Waiting for the session command to finish.";
    }

    function errorTitle() {
      return `${actionTitle(failedAction)} failed`;
    }

    function defaultFailureText(action) {
      if (action === "lock") return "Unable to start the lock screen.";
      if (action === "sleep") return "Unable to suspend the system.";
      if (action === "restart") return "Unable to restart the system.";
      if (action === "logout") return "Unable to log out of the current session.";
      if (action === "shutdown") return "Unable to power off the system.";
      return "Unable to complete the requested session action.";
    }

    function lockCommand() {
      const script = "command -v swaylock >/dev/null 2>&1 || { printf 'swaylock is not installed.\\n' >&2; exit 127; }; swaylock >/dev/null 2>&1 & pid=$!; sleep 0.15; if kill -0 \"$pid\" 2>/dev/null; then exit 0; fi; wait \"$pid\"";
      return ["sh", "-lc", script];
    }

    function logoutCommand() {
      return [
        "sh",
        "-lc",
        "if [ -n \"$XDG_SESSION_ID\" ]; then exec loginctl terminate-session \"$XDG_SESSION_ID\"; fi; session=\"$(loginctl show-user \"$USER\" -p Display --value 2>/dev/null)\"; if [ -n \"$session\" ]; then exec loginctl terminate-session \"$session\"; fi; printf 'Unable to determine current session.\\n' >&2; exit 1"
      ];
    }

    function fail(action, errorText) {
      failedAction = action;
      lastError = errorText !== "" ? errorText : defaultFailureText(action);
    }

    function dismissError() {
      failedAction = "";
      lastError = "";
    }

    function retry() {
      if (failedAction === "" || busy) return false;
      return run(failedAction);
    }

    function run(action) {
      const nextAction = String(action || "");
      if (busy || nextAction === "") return false;

      dismissError();
      busyAction = nextAction;

      if (nextAction === "lock") {
        lockProcess.exec(lockCommand());
        return true;
      }

      if (nextAction === "sleep") {
        actionProcess.exec(["systemctl", "suspend"]);
        return true;
      }

      if (nextAction === "restart") {
        actionProcess.exec(["systemctl", "reboot"]);
        return true;
      }

      if (nextAction === "shutdown") {
        actionProcess.exec(["systemctl", "poweroff"]);
        return true;
      }

      if (nextAction === "logout") {
        actionProcess.exec(logoutCommand());
        return true;
      }

      busyAction = "";
      fail(nextAction, `Unknown session action: ${nextAction}`);
      return false;
    }

    StdioCollector {
      id: actionStderr
      waitForEnd: true
    }

    Process {
      id: actionProcess

      stderr: actionStderr

      onExited: function(exitCode) {
        const actionName = controller.busyAction;
        const errorText = String(actionStderr.text || "").trim();
        controller.busyAction = "";
        if (exitCode === 0) {
          controller.dismissError();
          return;
        }

        controller.fail(actionName, errorText);
      }
    }

    StdioCollector {
      id: lockStderr
      waitForEnd: true
    }

    Process {
      id: lockProcess

      stderr: lockStderr

      onExited: function(exitCode) {
        const errorText = String(lockStderr.text || "").trim();
        controller.busyAction = "";
        if (exitCode === 0) {
          controller.dismissError();
          return;
        }

        controller.fail("lock", errorText);
      }
    }
  }

  component SessionActionBanner: UiSurface {
    id: banner

    required property var controller

    width: implicitWidth
    implicitWidth: Theme.popoverWidthSm + Theme.controlMd + Theme.gapLg
    implicitHeight: contentColumn.implicitHeight + Theme.insetLg
    tone: "panelOverlay"
    outlined: false
    radius: Theme.radiusLg
    border.width: Theme.stroke
    border.color: banner.controller.errorVisible ? Theme.accentStrong : Theme.border

    Column {
      id: contentColumn

      width: parent.width - Theme.insetLg
      anchors.left: parent.left
      anchors.leftMargin: Theme.insetSm
      anchors.top: parent.top
      anchors.topMargin: Theme.insetSm
      spacing: Theme.gapSm

      Row {
        width: parent.width
        spacing: Theme.gapSm

        Rectangle {
          width: Theme.controlMd
          height: Theme.controlMd
          radius: Theme.controlMd / 2
          color: banner.controller.errorVisible ? Theme.accent : Theme.field

          UiIcon {
            anchors.centerIn: parent
            name: banner.controller.actionIcon(banner.controller.errorVisible ? banner.controller.failedAction : banner.controller.busyAction)
            strokeColor: banner.controller.errorVisible ? Theme.textOnAccent : Theme.text
          }
        }

        Column {
          width: Math.max(0, parent.width - Theme.controlMd * 2 - Theme.gapLg)
          spacing: Theme.nudge

          UiText {
            width: parent.width
            text: banner.controller.errorVisible ? banner.controller.errorTitle() : banner.controller.busyTitle()
            size: "sm"
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
          }

          UiText {
            width: parent.width
            text: banner.controller.errorVisible ? banner.controller.lastError : banner.controller.busyDescription()
            size: "xs"
            tone: banner.controller.errorVisible ? "accent" : "subtle"
            wrapMode: Text.WordWrap
          }
        }

        Controls.IconButton {
          anchors.top: parent.top
          visible: banner.controller.errorVisible
          variant: "minimal"
          iconName: "x"
          onClicked: banner.controller.dismissError()
        }
      }

      Row {
        visible: banner.controller.errorVisible
        width: parent.width
        spacing: Theme.gapXs

        Controls.Button {
          text: "Retry"
          compact: true
          enabled: banner.controller.failedAction !== "" && !banner.controller.busy
          onClicked: banner.controller.retry()
        }

        Controls.Button {
          text: "Dismiss"
          compact: true
          onClicked: banner.controller.dismissError()
        }
      }
    }
  }

  SessionActionController {
    id: sessionActions
  }

  IpcHandler {
    target: "ui"
    function toggleControlCenter() {
      root.shadeOpen = !root.shadeOpen;
      if (root.shadeOpen) root.galleryOpen = false;
      if (root.shadeOpen) launcher.closeLauncher();
    }
    function showControlCenter() {
      root.shadeOpen = true;
      root.galleryOpen = false;
      launcher.closeLauncher();
    }
    function hideControlCenter() {
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
    visible: sessionActions.bannerVisible
    anchors { top: true; right: true }
    implicitWidth: sessionActionBanner.implicitWidth + Theme.gapLg + Theme.nudge
    implicitHeight: sessionActionBanner.implicitHeight + Theme.gapLg + Theme.nudge
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: sessionActions.errorVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    SessionActionBanner {
      id: sessionActionBanner

      controller: sessionActions
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: Theme.overlayMargin
      anchors.rightMargin: Theme.overlayMargin
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
      sessionActions: sessionActions
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: Theme.overlayMargin
      anchors.rightMargin: Theme.overlayMargin

      onCloseRequested: root.shadeOpen = false
    }
  }

  WidgetGalleryWindow {
    galleryOpen: root.galleryOpen
    onCloseRequested: root.galleryOpen = false
  }

}
