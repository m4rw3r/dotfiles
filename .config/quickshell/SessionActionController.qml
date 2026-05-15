pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

Item {
  id: controller

  property string busyAction: ""
  property string failedAction: ""
  property string lastError: ""
  readonly property bool busy: busyAction !== ""
  readonly property bool errorVisible: lastError !== ""
  readonly property bool bannerVisible: busy || errorVisible

  function actionTitle(action) {
    if (action === "lock")
      return "Lock";
    if (action === "sleep")
      return "Suspend";
    if (action === "restart")
      return "Restart";
    if (action === "logout")
      return "Log Out";
    if (action === "shutdown")
      return "Power Off";
    return "Session Action";
  }

  function actionIcon(action) {
    if (action === "lock")
      return "lock";
    if (action === "sleep")
      return "moon";
    if (action === "restart")
      return "restart";
    if (action === "logout")
      return "logout";
    if (action === "shutdown")
      return "power";
    return "alert-circle";
  }

  function busyTitle() {
    return `${actionTitle(busyAction)} in progress`;
  }

  function busyDescription() {
    if (busyAction === "lock")
      return "Waiting for the lock screen to take over.";
    return "Waiting for the session command to finish.";
  }

  function errorTitle() {
    return `${actionTitle(failedAction)} failed`;
  }

  function defaultFailureText(action) {
    if (action === "lock")
      return "Unable to start the lock screen.";
    if (action === "sleep")
      return "Unable to suspend the system.";
    if (action === "restart")
      return "Unable to restart the system.";
    if (action === "logout")
      return "Unable to log out of the current session.";
    if (action === "shutdown")
      return "Unable to power off the system.";
    return "Unable to complete the requested session action.";
  }

  function lockCommand() {
    const script = "command -v swaylock >/dev/null 2>&1 || { printf 'swaylock is not installed.\\n' >&2; exit 127; }; swaylock >/dev/null 2>&1 & pid=$!; sleep 0.15; if kill -0 \"$pid\" 2>/dev/null; then exit 0; fi; wait \"$pid\"";
    return ["sh", "-lc", script];
  }

  function logoutCommand() {
    return ["sh", "-lc", "if [ -n \"$XDG_SESSION_ID\" ]; then exec loginctl terminate-session \"$XDG_SESSION_ID\"; fi; session=\"$(loginctl show-user \"$USER\" -p Display --value 2>/dev/null)\"; if [ -n \"$session\" ]; then exec loginctl terminate-session \"$session\"; fi; printf 'Unable to determine current session.\\n' >&2; exit 1"];
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
    if (failedAction === "" || busy)
      return false;
    return run(failedAction);
  }

  function run(action) {
    const nextAction = String(action || "");
    if (busy || nextAction === "")
      return false;

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

    Component.onCompleted: exited.connect(function (exitCode) {
      const actionName = controller.busyAction;
      const errorText = String(actionStderr.text || "").trim();
      controller.busyAction = "";
      if (exitCode === 0) {
        controller.dismissError();
        return;
      }

      controller.fail(actionName, errorText);
    })
  }

  StdioCollector {
    id: lockStderr
    waitForEnd: true
  }

  Process {
    id: lockProcess

    stderr: lockStderr

    Component.onCompleted: exited.connect(function (exitCode) {
      const errorText = String(lockStderr.text || "").trim();
      controller.busyAction = "";
      if (exitCode === 0) {
        controller.dismissError();
        return;
      }

      controller.fail("lock", errorText);
    })
  }
}
