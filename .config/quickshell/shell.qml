//@ pragma UseQApplication
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import "theme"
import "ui/controls" as Controls
import "ui/primitives"

ShellRoot {
  id: root

  property bool shadeOpen: false
  property bool galleryOpen: false
  property string trayMode: "hidden"
  property bool trayUserPinned: false
  property bool trayPeekForced: false
  property int trayAttentionCount: 0
  property bool volumeOverlayActive: false
  property bool volumeOverlayInitialized: false
  property real volumeOverlayValue: 0
  property bool volumeOverlayMuted: false
  readonly property var volumeTrackedSink: Pipewire.defaultAudioSink
  readonly property bool trayHasAttention: trayAttentionCount > 0
  // qmllint disable missing-property
  readonly property bool trayHasItems: trayTracker.count > 0
  // qmllint enable missing-property

  function refreshTrayState() {
    let attention = 0;
    // qmllint disable missing-property
    for (let i = 0; i < SystemTray.items.count; i += 1) {
      const item = SystemTray.items.get(i);
      if (item && item.status === Status.NeedsAttention) attention += 1;
    }
    // qmllint enable missing-property
    trayAttentionCount = attention;
  }

  function normalizeVolumeValue(value) {
    return Math.max(0, Math.min(1, Number(value) || 0));
  }

  function syncVolumeOverlayFromTrackedSink(shouldReveal) {
    const sink = volumeTrackedSink;
    const audio = sink && sink.audio ? sink.audio : null;
    if (!Pipewire.ready || !sink || !sink.ready || !audio) {
      if (!sink) volumeOverlayInitialized = false;
      return;
    }

    const nextVolume = normalizeVolumeValue(audio.volume);
    const nextMuted = !!audio.muted;
    const volumeChanged = !volumeOverlayInitialized
      || Math.abs(nextVolume - volumeOverlayValue) > 0.0005
      || nextMuted !== volumeOverlayMuted;

    volumeOverlayValue = nextVolume;
    volumeOverlayMuted = nextMuted;

    if (!volumeOverlayInitialized) {
      volumeOverlayInitialized = true;
      return;
    }

    if (shouldReveal && volumeChanged && !root.shadeOpen) {
      volumeOverlayActive = true;
      volumeOverlayTimer.restart();
    }
  }

  function collapseTrayToPeekOrHidden() {
    trayUserPinned = false;
    trayMode = (trayPeekForced || trayHasAttention) ? "peek" : "hidden";
  }

  function openTrayFromPeek() {
    trayPeekForced = false;
    trayUserPinned = true;
    trayMode = "expanded";
  }

  function openTrayFromControlCenter() {
    trayPeekForced = false;
    trayUserPinned = false;
    trayMode = "expanded";
  }

  function toggleTrayFromControlCenter() {
    if (trayMode === "hidden" || trayMode === "peek") {
      openTrayFromControlCenter();
      return;
    }

    closeTray();
  }

  function forceTrayPeek() {
    trayPeekForced = true;
    trayUserPinned = false;
    trayMode = "peek";
  }

  function closeTray() {
    trayPeekForced = false;
    trayUserPinned = false;
    trayMode = trayHasAttention ? "peek" : "hidden";
  }

  function openControlCenter() {
    shadeOpen = true;
    galleryOpen = false;
    launcher.closeLauncher();
  }

  function closeControlCenter() {
    shadeOpen = false;
    if (!trayUserPinned) collapseTrayToPeekOrHidden();
  }

  Component.onCompleted: syncVolumeOverlayFromTrackedSink(false)

  onShadeOpenChanged: {
    if (!shadeOpen) return;
    volumeOverlayActive = false;
    volumeOverlayTimer.stop();
  }

  onVolumeTrackedSinkChanged: {
    volumeOverlayInitialized = false;
    syncVolumeOverlayFromTrackedSink(false);
  }

  onTrayHasAttentionChanged: {
    if (trayHasAttention) {
      if (trayMode === "hidden") trayMode = "peek";
      return;
    }

    if (trayMode === "peek" && !trayPeekForced) trayMode = "hidden";
  }

  Instantiator {
    id: trayTracker

    model: SystemTray.items

    delegate: Item {
      id: trayTrackerItem

      required property var modelData
      visible: false
      width: 0
      height: 0

      Connections {
        target: trayTrackerItem.modelData
        ignoreUnknownSignals: true

        function onStatusChanged() {
          Qt.callLater(root.refreshTrayState);
        }

        function onReady() {
          Qt.callLater(root.refreshTrayState);
        }
      }
    }

    onObjectAdded: Qt.callLater(root.refreshTrayState)
    onObjectRemoved: Qt.callLater(root.refreshTrayState)
  }

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

      Component.onCompleted: exited.connect(function(exitCode) {
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

      Component.onCompleted: exited.connect(function(exitCode) {
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

  NotificationCenter {
    id: notifications
  }

  PwObjectTracker {
    objects: [root.volumeTrackedSink]
  }

  Timer {
    id: volumeOverlayTimer
    interval: 1100
    repeat: false
    onTriggered: root.volumeOverlayActive = false
  }

  Connections {
    target: Pipewire
    ignoreUnknownSignals: true

    function onReadyChanged() {
      root.syncVolumeOverlayFromTrackedSink(false);
    }
  }

  Connections {
    target: root.volumeTrackedSink
    ignoreUnknownSignals: true

    function onReadyChanged() {
      root.syncVolumeOverlayFromTrackedSink(false);
    }
  }

  Connections {
    target: root.volumeTrackedSink && root.volumeTrackedSink.audio ? root.volumeTrackedSink.audio : null
    ignoreUnknownSignals: true

    function onVolumeChanged() {
      root.syncVolumeOverlayFromTrackedSink(true);
    }

    function onMutedChanged() {
      root.syncVolumeOverlayFromTrackedSink(true);
    }
  }

  IpcHandler {
    target: "ui"
    function toggleControlCenter() {
      if (root.shadeOpen) root.closeControlCenter();
      else root.openControlCenter();
    }
    function showControlCenter() {
      root.openControlCenter();
    }
    function hideControlCenter() {
      root.closeControlCenter();
    }
  }

  IpcHandler {
    target: "tray"

    function toggle() {
      if (root.trayMode === "expanded") root.closeTray();
      else {
        root.trayPeekForced = false;
        root.trayUserPinned = true;
        root.trayMode = "expanded";
      }
    }

    function open() {
      root.trayPeekForced = false;
      root.trayUserPinned = true;
      root.trayMode = "expanded";
    }

    function peek() {
      root.forceTrayPeek();
    }

    function close() {
      root.closeTray();
    }
  }

  IpcHandler {
    target: "gallery"

    function toggle() {
      root.galleryOpen = !root.galleryOpen;
      if (root.galleryOpen) {
        root.closeControlCenter();
        launcher.closeLauncher();
      }
    }

    function open() {
      root.galleryOpen = true;
      root.closeControlCenter();
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
      root.closeControlCenter();
      root.galleryOpen = false;
    }
  }

  // qmllint disable uncreatable-type
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
  // qmllint enable uncreatable-type

  // qmllint disable uncreatable-type
  PanelWindow {
    id: toastWindow

    readonly property real anchorOffsetY: {
      let offset = 0;
      if (sessionActions.bannerVisible) offset = Math.max(offset, sessionActionBanner.implicitHeight + Theme.gapSm);
      if (root.trayMode !== "hidden") offset = Math.max(offset, standaloneTray.implicitHeight + Theme.gapSm);
      return offset;
    }

    visible: notifications.toastUids.length > 0 && !root.shadeOpen && !root.galleryOpen && !launcher.launcherOpen
    anchors { top: true; right: true }
    implicitWidth: toastStack.implicitWidth + Theme.overlayMargin * 2
    implicitHeight: toastStack.implicitHeight + Theme.overlayMargin * 2 + anchorOffsetY
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    NotificationToastStack {
      id: toastStack

      notificationCenter: notifications
      suspended: !toastWindow.visible
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: Theme.overlayMargin + toastWindow.anchorOffsetY
      anchors.rightMargin: Theme.overlayMargin
    }
  }
  // qmllint enable uncreatable-type

  // qmllint disable uncreatable-type
  PanelWindow {
    id: trayWindow

    visible: root.trayMode !== "hidden" && !root.shadeOpen && !root.galleryOpen && !launcher.launcherOpen
    anchors { top: true; right: true }
    implicitWidth: standaloneTray.implicitWidth + Theme.overlayMargin * 2
    implicitHeight: standaloneTray.implicitHeight + Theme.overlayMargin * 2
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.trayMode === "expanded" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onVisibleChanged: {
      if (visible && root.trayMode === "expanded") standaloneTray.forceActiveFocus();
    }

    TrayRail {
      id: standaloneTray

      mode: root.trayMode
      forcedVisible: root.trayPeekForced
      controlCenterOpen: false
      panelWindow: trayWindow
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: Theme.overlayMargin
      anchors.rightMargin: Theme.overlayMargin

      onDismissRequested: root.closeTray()
      onExpandRequested: root.openTrayFromPeek()
    }
  }
  // qmllint enable uncreatable-type

  // qmllint disable uncreatable-type
  PanelWindow {
    id: volumeOverlayWindow

    visible: volumeHud.visible && !root.shadeOpen
    anchors { top: true; bottom: true; right: true }
    implicitWidth: volumeHud.implicitWidth + Theme.overlayMargin * 2
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    VolumeOverlay {
      id: volumeHud

      value: root.volumeOverlayValue
      muted: root.volumeOverlayMuted
      active: root.volumeOverlayActive
      anchors.right: parent.right
      anchors.rightMargin: Theme.overlayMargin
      anchors.verticalCenter: parent.verticalCenter
    }
  }
  // qmllint enable uncreatable-type

  // qmllint disable uncreatable-type
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
        onClicked: root.closeControlCenter()
      }
    }
  }
  // qmllint enable uncreatable-type

  // qmllint disable uncreatable-type
  PanelWindow {
    id: controlCenterWindow

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
        else root.closeControlCenter();
      }
    }

    TrayRail {
      id: companionTray

      visible: root.trayMode !== "hidden"
      mode: root.trayMode
      forcedVisible: root.trayPeekForced
      controlCenterOpen: true
      panelWindow: controlCenterWindow
      anchors.top: controlCenter.top
      anchors.right: controlCenter.left
      anchors.rightMargin: Theme.gapSm

      onDismissRequested: root.closeTray()
      onExpandRequested: root.openTrayFromPeek()
    }

    ControlCenter {
      id: controlCenter

      panelOpen: root.shadeOpen
      notificationCenter: notifications
      sessionActions: sessionActions
      trayVisible: root.trayMode !== "hidden"
      trayExpanded: root.trayMode === "expanded"
      trayNeedsAttention: root.trayHasAttention
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: Theme.overlayMargin
      anchors.rightMargin: Theme.overlayMargin

      onTrayToggleRequested: root.toggleTrayFromControlCenter()
      onCloseRequested: root.closeControlCenter()
    }
  }
  // qmllint enable uncreatable-type

  WidgetGalleryWindow {
    galleryOpen: root.galleryOpen
    onCloseRequested: root.galleryOpen = false
  }

}
