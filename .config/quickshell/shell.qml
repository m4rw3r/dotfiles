//@ pragma UseQApplication
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "theme"
import "ui/primitives"

ShellRoot {
  id: root

  // One of "", "controlCenter", "launcher", or "gallery". This keeps overlay exclusivity centralized.
  property string activeOverlay: ""
  readonly property bool shadeOpen: activeOverlay === "controlCenter"
  readonly property bool galleryOpen: activeOverlay === "gallery"

  function openControlCenter() {
    activeOverlay = "controlCenter";
    launcher.closeLauncher();
  }

  function closeControlCenter() {
    if (activeOverlay === "controlCenter")
      activeOverlay = "";
    if (!trayState.userPinned)
      trayState.collapseToPeekOrHidden();
  }

  function openGallery() {
    if (activeOverlay === "controlCenter" && !trayState.userPinned)
      trayState.collapseToPeekOrHidden();
    activeOverlay = "gallery";
    launcher.closeLauncher();
  }

  function closeGallery() {
    if (activeOverlay === "gallery")
      activeOverlay = "";
  }

  function toggleGallery() {
    if (galleryOpen)
      closeGallery();
    else
      openGallery();
  }

  function beginLauncherOverlay() {
    if (activeOverlay === "controlCenter" && !trayState.userPinned)
      trayState.collapseToPeekOrHidden();
    activeOverlay = "launcher";
  }

  function clearLauncherOverlay() {
    if (activeOverlay === "launcher")
      activeOverlay = "";
  }

  SessionActionController {
    id: sessionActions
  }

  NotificationCenter {
    id: notifications
  }

  VolumeOverlayController {
    id: volumeOverlayController

    overlayBlocked: root.activeOverlay !== ""
  }

  TrayStateController {
    id: trayState
  }

  IpcHandler {
    target: "ui"
    function toggleControlCenter() {
      if (root.shadeOpen)
        root.closeControlCenter();
      else
        root.openControlCenter();
    }
    function showControlCenter() {
      root.openControlCenter();
    }
    function hideControlCenter() {
      root.closeControlCenter();
    }
  }

  IpcHandler {
    target: "volume"

    function flash() {
      volumeOverlayController.flash();
    }
  }

  IpcHandler {
    target: "tray"

    function toggle() {
      trayState.toggle();
    }

    function open() {
      trayState.open();
    }

    function peek() {
      trayState.forcePeek();
    }

    function close() {
      trayState.close();
    }
  }

  IpcHandler {
    target: "gallery"

    function toggle() {
      root.toggleGallery();
    }

    function open() {
      root.openGallery();
    }

    function close() {
      root.closeGallery();
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

    onLauncherOpening: root.beginLauncherOverlay()
    onLauncherOpenChanged: {
      if (!launcherOpen)
        root.clearLauncherOverlay();
    }
    onLauncherClosed: root.clearLauncherOverlay()
  }

  // qmllint disable uncreatable-type
  PanelWindow {
    visible: sessionActions.bannerVisible
    anchors {
      top: true
      right: true
    }
    implicitWidth: sessionActionBanner.implicitWidth + Theme.gapLg + Theme.nudge
    implicitHeight: sessionActionBanner.implicitHeight + Theme.gapLg + Theme.nudge
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
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
      if (sessionActions.bannerVisible)
        offset = Math.max(offset, sessionActionBanner.implicitHeight + Theme.gapSm);
      if (trayState.mode !== "hidden")
        offset = Math.max(offset, standaloneTray.implicitHeight + Theme.gapSm);
      return offset;
    }

    visible: notifications.toastUids.length > 0 && root.activeOverlay === ""
    anchors {
      top: true
      right: true
    }
    implicitWidth: toastStack.implicitWidth + Theme.overlayMargin * 2
    implicitHeight: toastStack.implicitHeight + Theme.overlayMargin * 2 + anchorOffsetY
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
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

    visible: trayState.mode !== "hidden" && root.activeOverlay === ""
    anchors {
      top: true
      right: true
    }
    implicitWidth: standaloneTray.implicitWidth + Theme.overlayMargin * 2
    implicitHeight: standaloneTray.implicitHeight + Theme.overlayMargin * 2
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: trayState.mode === "expanded" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onVisibleChanged: {
      if (visible && trayState.mode === "expanded")
        standaloneTray.forceActiveFocus();
    }

    TrayRail {
      id: standaloneTray

      mode: trayState.mode
      forcedVisible: trayState.peekForced
      stateController: trayState
      controlCenterOpen: false
      panelWindow: trayWindow
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: Theme.overlayMargin
      anchors.rightMargin: Theme.overlayMargin

      onDismissRequested: trayState.close()
      onExpandRequested: trayState.openFromPeek()
    }
  }
  // qmllint enable uncreatable-type

  // qmllint disable uncreatable-type
  PanelWindow {
    id: volumeOverlayWindow

    visible: true
    anchors {
      top: true
      bottom: true
      right: true
    }
    implicitWidth: volumeHud.implicitWidth + Theme.overlayMargin * 2
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    color: "transparent"
    mask: Region {
      width: 0
      height: 0
    }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    VolumeOverlay {
      id: volumeHud

      value: volumeOverlayController.value
      muted: volumeOverlayController.muted
      active: volumeOverlayController.active
      anchors.right: parent.right
      anchors.rightMargin: Theme.overlayMargin
      anchors.verticalCenter: parent.verticalCenter
    }
  }
  // qmllint enable uncreatable-type

  // qmllint disable uncreatable-type
  PanelWindow {
    visible: root.shadeOpen
    anchors {
      left: true
      right: true
      top: true
      bottom: true
    }
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
    anchors {
      left: true
      right: true
      top: true
      bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    onVisibleChanged: {
      if (visible)
        controlCenter.forceActiveFocus();
    }

    MouseArea {
      anchors.fill: parent
      onClicked: {
        if (controlCenter.popupDismissInProgress)
          return;
        if (controlCenter.overlayDismissActive)
          controlCenter.dismissOverlaySection();
        else
          root.closeControlCenter();
      }
    }

    TrayRail {
      id: companionTray

      visible: trayState.mode !== "hidden"
      mode: trayState.mode
      forcedVisible: trayState.peekForced
      stateController: trayState
      controlCenterOpen: true
      panelWindow: controlCenterWindow
      anchors.top: controlCenter.top
      anchors.right: controlCenter.left
      anchors.rightMargin: Theme.gapSm

      onDismissRequested: trayState.close()
      onExpandRequested: trayState.openFromPeek()
    }

    ControlCenter {
      id: controlCenter

      audioSink: volumeOverlayController.trackedSink
      panelOpen: root.shadeOpen
      popupParentWindow: controlCenterWindow
      notificationCenter: notifications
      sessionActions: sessionActions
      trayVisible: trayState.mode !== "hidden"
      trayExpanded: trayState.mode === "expanded"
      trayNeedsAttention: trayState.hasAttention
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: Theme.overlayMargin
      anchors.rightMargin: Theme.overlayMargin

      onTrayToggleRequested: trayState.toggleFromControlCenter()
      onCloseRequested: root.closeControlCenter()
    }
  }
  // qmllint enable uncreatable-type

  Loader {
    active: root.galleryOpen

    sourceComponent: Component {
      WidgetGalleryWindow {
        galleryOpen: root.galleryOpen
        onCloseRequested: root.closeGallery()
      }
    }
  }
}
