pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import "services" as Services
import "controlcenter" as ControlCenterParts
import "theme"
import "ui/primitives"
import "ui/controls" as Controls
import "ui/patterns" as Patterns

FocusScope {
  id: root

  signal closeRequested()
  signal trayToggleRequested()

  implicitWidth: 344
  implicitHeight: panel.implicitHeight

  property string expandedSection: ""
  property string pendingPowerAction: ""
  property string wifiPasswordTarget: ""
  property string wifiPassword: ""
  property bool powerProfileBusy: false
  property bool onScreenKeyboardBusy: false
  property bool onScreenKeyboardFailed: false
  property string onScreenKeyboardMessage: ""
  property bool keyboardRecoveryBusy: false
  property bool keyboardRecoveryFailed: false
  property string keyboardRecoveryMessage: ""
  property real pendingAudioVolume: 0
  property real pendingScreenBrightness: 0
  property bool panelOpen: false
  property bool trayVisible: false
  property bool trayExpanded: false
  property bool trayNeedsAttention: false
  property var notificationCenter: null
  property var expandedNotificationGroups: ({})
  property string notificationReturnSection: ""
  property var sessionActions: null
  property string bluetoothAdapterKey: "defaultAdapter"
  property bool initialLoadDeadlineElapsed: false
  property int initialLoadDeadlineMs: 50
  readonly property bool sessionActionBusy: !!sessionActions && sessionActions.busyAction !== ""
  readonly property bool notificationsOpen: expandedSection === "notifications"
  readonly property int notificationCount: notificationCenter ? notificationCenter.trackedCount : 0
  readonly property int unreadNotificationCount: notificationCenter ? notificationCenter.unreadCount : 0
  readonly property bool notificationsCriticalUnread: notificationCenter ? notificationCenter.hasCriticalUnread : false
  readonly property var latestNotificationEntry: notificationCenter ? notificationCenter.latestEntry : null
  readonly property var footerNotificationEntry: notificationCenter ? notificationCenter.footerEntry : null
  readonly property real notificationViewportMaxHeight: Math.max(
    Theme.controlMd * 4,
    Math.min(Theme.controlMd * 8, parent ? parent.height * 0.36 : Theme.controlMd * 6)
  )
  readonly property int bluetoothScanVisibleRowCount: 6
  readonly property real bluetoothScanViewportMaxHeight: Theme.controlMd * bluetoothScanVisibleRowCount + 4 * (bluetoothScanVisibleRowCount - 1)
  readonly property bool powerMenuOpen: expandedSection === "power"
  readonly property bool outputMenuOpen: expandedSection === "outputs"
  readonly property bool selectorPopoverOpen: expandedSection === "profile" || (expandedSection === "lighting" && lightingService.commandAvailable)
  readonly property bool tileMenuOpen: expandedSection === "wifi" || expandedSection === "bluetooth"
  readonly property bool overlayDismissActive: selectorPopoverOpen || tileMenuOpen || powerMenuOpen || outputMenuOpen || notificationsOpen
  readonly property var audioSink: Pipewire.defaultAudioSink
  readonly property var battery: UPower.displayDevice
  readonly property bool batteryAvailable: battery && battery.isPresent && battery.isLaptopBattery
  readonly property bool audioReady: audioService.ready
  readonly property bool audioLoading: panelOpen && !audioService.settled
  readonly property bool brightnessLoading: panelOpen && !brightnessService.settled
  readonly property bool wifiLoading: panelOpen && !wifiService.ready
  readonly property var powerMenuEntries: [
    { kind: "action", title: "Lock", action: "lock", confirm: false },
    { kind: "action", title: "Suspend", action: "sleep", confirm: false },
    { kind: "action", title: "Restart", action: "restart", confirm: true },
    { kind: "action", title: "Power Off", action: "shutdown", confirm: true },
    { kind: "divider" },
    { kind: "action", title: "Log Out", action: "logout", confirm: true }
  ]
  readonly property var profileOptions: [
    {
      title: "Performance",
      profile: PowerProfile.Performance,
      enabled: PowerProfiles.hasPerformanceProfile,
      dividerVisible: true
    },
    {
      title: "Balanced",
      profile: PowerProfile.Balanced,
      enabled: true,
      dividerVisible: true
    },
    {
      title: "Power Saver",
      profile: PowerProfile.PowerSaver,
      enabled: true,
      dividerVisible: false
    }
  ]
  readonly property var lightingOptions: [
    { title: "Off", index: 0, dividerVisible: true },
    { title: "Low", index: 1, dividerVisible: true },
    { title: "Medium", index: 2, dividerVisible: true },
    { title: "High", index: 3, dividerVisible: false }
  ]

  Component.onCompleted: {
    refreshPanelData();
    panelRefreshTimer.restart();
  }
  onNotificationsOpenChanged: {
    if (notificationsOpen && unreadNotificationCount > 0) notificationReadTimer.restart();
    else notificationReadTimer.stop();
  }

  function clamp(value, minValue, maxValue) {
    return Math.max(minValue, Math.min(maxValue, value));
  }

  function toggleSection(section) {
    if (expandedSection === "notifications" && section !== "notifications") notificationReturnSection = "";
    expandedSection = expandedSection === section ? "" : section;
    if (expandedSection !== "wifi") {
      wifiPasswordTarget = "";
      wifiPassword = "";
    }
    if (expandedSection !== "power") pendingPowerAction = "";
    if (expandedSection === "wifi") wifiService.refresh();
    if (expandedSection === "bluetooth") bluetoothService.refreshRfkillState();
    if (expandedSection !== "bluetooth") bluetoothService.stopDiscovery();
  }

  function toggleNotificationsSection() {
    if (notificationsOpen) {
      expandedSection = notificationReturnSection;
      notificationReturnSection = "";
      return;
    }

    notificationReturnSection = expandedSection === "notifications" ? "" : expandedSection;
    expandedSection = "notifications";
  }

  function isNotificationGroupExpanded(groupKey) {
    return !!expandedNotificationGroups[groupKey];
  }

  function toggleNotificationGroup(groupKey) {
    const nextState = Object.assign({}, expandedNotificationGroups);
    nextState[groupKey] = !nextState[groupKey];
    expandedNotificationGroups = nextState;
  }

  function clearNotificationGroup(groupKey) {
    if (notificationCenter) notificationCenter.forgetGroup(groupKey);

    const nextState = Object.assign({}, expandedNotificationGroups);
    delete nextState[groupKey];
    expandedNotificationGroups = nextState;
  }

  function popupX(anchorItem, popupWidth, alignRight) {
    if (!anchorItem || !panel) return 0;
    const position = anchorItem.mapToItem(panel, 0, 0);
    const maxX = Math.max(0, panel.width - popupWidth);
    const rawX = alignRight ? position.x + anchorItem.width - popupWidth : position.x;
    return clamp(rawX, 0, maxX);
  }

  function popupY(anchorItem, spacing) {
    if (!anchorItem || !panel) return 0;
    const position = anchorItem.mapToItem(panel, 0, 0);
    return position.y + anchorItem.height + (spacing || 8);
  }

  function popupOverlayY(anchorItem, popupHeight) {
    if (!anchorItem || !panel) return 0;
    const position = anchorItem.mapToItem(panel, 0, 0);
    const maxY = Math.max(0, panel.height - popupHeight);
    const rawY = position.y + (anchorItem.height - popupHeight) / 2;
    return clamp(rawY, 0, maxY);
  }

  function dismissOverlaySection() {
    if (!overlayDismissActive) return;
    if (notificationsOpen) {
      toggleNotificationsSection();
      return;
    }

    toggleSection(expandedSection);
  }

  function batterySummary() {
    if (!batteryAvailable) return "N/A";

    const rawPercent = Number(battery.percentage || 0);
    const scaledPercent = rawPercent <= 1.5 ? rawPercent * 100 : rawPercent;
    const percent = `${Math.round(scaledPercent)}%`;

    return percent;

    /*
    // const state = battery.state;
    if (state === UPowerDeviceState.FullyCharged) return `${percent} Full`;
    if (state === UPowerDeviceState.Charging || state === UPowerDeviceState.PendingCharge) return `${percent} Charging`;
    if (state === UPowerDeviceState.Empty) return `${percent} Empty`;
    return percent;
    */
  }

  function batteryIconName() {
    if (!batteryAvailable) return "battery";

    const state = battery.state;
    if (state === UPowerDeviceState.Charging || state === UPowerDeviceState.PendingCharge) return "battery-charging";
    return "battery";
  }

  function normalizePowerAction(action) {
    if (action === "sleep") return "suspend";
    return action;
  }

  function powerActionTitle(action) {
    if (action === "lock") return "Lock";
    if (action === "suspend" || action === "sleep") return "Suspend";
    if (action === "restart") return "Restart";
    if (action === "logout") return "Log Out";
    return "Power Off";
  }

  function powerActionIcon(action) {
    if (action === "lock") return "lock";
    if (action === "suspend" || action === "sleep") return "moon";
    if (action === "restart") return "restart";
    if (action === "logout") return "logout";
    return "power";
  }

  function powerHeroAction() {
    if (sessionActionBusy) return normalizePowerAction(sessionActions.busyAction);
    return pendingPowerAction !== "" ? pendingPowerAction : "shutdown";
  }

  function powerHeroHint() {
    if (sessionActionBusy) return `${powerActionTitle(sessionActions.busyAction)} in progress...`;
    if (pendingPowerAction !== "") return "Press the highlighted action again to confirm";
    return "";
  }

  function wifiTileTitle() {
    if (!wifiService.ready) return "Wi-Fi";
    if (!wifiService.enabled || wifiService.connectedSsid === "") return "Wi-Fi";
    return wifiService.connectedSsid;
  }

  function wifiHeroHint() {
    if (!wifiService.ready) return initialLoadDeadlineElapsed ? "Loading Wi-Fi..." : "";
    if (wifiService.lastError !== "") return "Unavailable";
    if (!wifiService.hardwareEnabled) return "Wi-Fi hardware is blocked.";
    if (!wifiService.enabled) return "Wi-Fi is off";
    if (wifiService.connectedSsid !== "") return `${wifiService.connectedSignal}% signal`;
    if (wifiService.networks.length > 0) return `${wifiService.networks.length} networks available`;
    return "No networks available";
  }

  function wifiNetworkSubtitle(network) {
    if (!network) return "";

    const securityLabel = network.security !== "" ? network.security : "open";
    const savedLabel = network.known ? ", saved" : "";
    return `${network.signal}%, ${securityLabel}${savedLabel}`;
  }

  function bluetoothTileTitle() {
    const count = bluetoothService.connectedCount;
    if (count > 0) return count === 1 ? "1 Device" : `${count} Devices`;
    return "Bluetooth";
  }

  function bluetoothTileSubtitle() {
    if (!bluetoothService.adapter) return "Unavailable";
    if (bluetoothService.busy && bluetoothService.enableAfterUnblock) return "Unblocking...";
    if (bluetoothService.hardBlocked) return "Hardware Blocked";
    if (bluetoothService.blocked) return "Blocked";
    if (!bluetoothService.enabled) return "Off";
    return bluetoothService.discovering ? "Scanning" : "Ready";
  }

  function bluetoothDeviceText(value) {
    return String(value || "").trim();
  }

  function isBluetoothIdentifier(value) {
    return /^([0-9A-F]{2}[:-]){5}[0-9A-F]{2}$/i.test(bluetoothDeviceText(value));
  }

  function bluetoothDeviceTitle(device) {
    if (!device) return "";

    const alias = bluetoothDeviceText(device.name);
    const deviceName = bluetoothDeviceText(device.deviceName);
    const address = bluetoothDeviceText(device.address);

    if (alias !== "" && !isBluetoothIdentifier(alias)) return alias;
    if (deviceName !== "" && !isBluetoothIdentifier(deviceName)) return deviceName;
    if (alias !== "") return alias;
    if (deviceName !== "") return deviceName;
    return address;
  }

  function bluetoothDeviceAddressLabel(device) {
    if (!device) return "";

    const title = bluetoothDeviceTitle(device);
    const address = bluetoothDeviceText(device.address);
    if (address === "" || title === address) return "";
    return address;
  }

  function bluetoothConnectedSubtitle(device) {
    if (!device) return "";

    const parts = [];
    parts.push(device.batteryAvailable ? `${Math.round(device.battery * 100)}% battery` : "Connected");

    const addressLabel = bluetoothDeviceAddressLabel(device);
    if (addressLabel !== "") parts.push(addressLabel);
    return parts.join(" - ");
  }

  function bluetoothAvailableSubtitle(device) {
    if (!device) return "";

    const parts = [device.paired || device.bonded ? "Paired" : "Available"];
    const addressLabel = bluetoothDeviceAddressLabel(device);
    if (addressLabel !== "") parts.push(addressLabel);
    return parts.join(" - ");
  }

  function bluetoothBlockedMessage() {
    if (!bluetoothService.blocked) return "";
    if (bluetoothService.busy && bluetoothService.enableAfterUnblock) return "Unblocking Bluetooth...";
    if (bluetoothService.hardBlocked) return "Bluetooth is blocked by hardware or firmware airplane mode.";
    if (bluetoothService.softBlocked) return "Bluetooth is blocked by rfkill. Turn On will unblock it.";
    if (!bluetoothService.rfkillKnown) return "Bluetooth is blocked. Turn On will try to unblock it.";
    return "Bluetooth is blocked.";
  }

  function bluetoothPrimaryActionText() {
    if (bluetoothService.busy && bluetoothService.enableAfterUnblock) return "Unblocking...";
    if (bluetoothService.hardBlocked) return "Blocked";
    return bluetoothService.enabled ? "Turn Off" : "Turn On";
  }

  function profileShortLabel() {
    if (PowerProfiles.profile === PowerProfile.PowerSaver) return "Power Saver";
    if (PowerProfiles.profile === PowerProfile.Performance) return "Performance";
    return "Balanced";
  }

  function profileCommandValue(profile) {
    if (profile === PowerProfile.PowerSaver) return "quiet";
    if (profile === PowerProfile.Performance) return "performance";
    return "balanced";
  }

  function selectPowerProfile(profile) {
    powerProfileBusy = true;
    expandedSection = "";
    powerProfileWriteProcess.exec(["z13ctl", "profile", "--set", profileCommandValue(profile)]);
  }

  function lightingTileTitle() {
    if (lightingService.commandAvailable && !lightingService.available) return "Unavailable";
    return lightingLevelLabel(lightingLevelIndex());
  }

  function lightingLevelKey(index) {
    if (index === 3) return "high";
    if (index === 2) return "medium";
    if (index === 1) return "low";
    return "off";
  }

  function lightingLevelIndex() {
    if (lightingService.level === "high") return 3;
    if (lightingService.level === "medium") return 2;
    if (lightingService.level === "low") return 1;
    return 0;
  }

  function lightingLevelLabel(index) {
    if (index === 3) return "High";
    if (index === 2) return "Medium";
    if (index === 1) return "Low";
    return "Off";
  }

  function setLightingLevel(index) {
    if (!lightingService.available) return;
    expandedSection = "";
    lightingService.applyLevel(lightingLevelKey(index));
  }

  function outputLabel(node) {
    if (!node) return "Unknown output";
    return node.description || node.nickname || node.name || "Unknown output";
  }

  function outputMenuTitle() {
    if (audioSink) return outputLabel(audioSink);
    return "Sound Output";
  }

  function outputMenuSubtitle() {
    if (!Pipewire.ready) return initialLoadDeadlineElapsed ? "Loading audio..." : "";
    if (!audioReady) return audioService.lastError !== "" ? "Unavailable" : "Audio unavailable";
    return audioVolumePercentText();
  }

  function audioVolumeValue() {
    if (!audioReady) return 0;
    return clamp(Number(audioService.volume), 0, 1);
  }

  function audioVolumePercentText() {
    if (!audioReady) return "Unavailable";
    if (audioService.muted) return "Muted";
    return `${Math.round(audioVolumeValue() * 100)}%`;
  }

  function refreshPanelData() {
    audioService.refresh();
    brightnessService.refresh();
    lightingService.refresh();
    wifiService.refresh();
    bluetoothService.refreshRfkillState();
    pendingAudioVolume = audioService.volume;
    pendingScreenBrightness = brightnessService.screenPercent;
  }

  function beginWifiConnect(network) {
    if (!network) return;

    wifiService.lastError = "";

    if (!network.secure || network.known) {
      wifiPasswordTarget = "";
      wifiPassword = "";
      wifiService.connectNetwork(network.ssid, "");
      return;
    }

    expandedSection = "wifi";
    wifiPasswordTarget = network.ssid;
    wifiPassword = "";
  }

  function submitWifiPassword() {
    if (wifiPasswordTarget === "" || wifiPassword === "") return;
    wifiService.connectNetwork(wifiPasswordTarget, wifiPassword);
  }

  function runSessionAction(action) {
    if (!sessionActions || sessionActionBusy) return;

    pendingPowerAction = "";
    root.closeRequested();

    Qt.callLater(function() {
      sessionActions.run(action);
    });
  }

  function triggerPowerAction(action) {
    if (pendingPowerAction === action) {
      runSessionAction(action);
      return;
    }

    pendingPowerAction = action;
    powerConfirmTimer.restart();
  }

  function toggleWifiEnabled() {
    wifiService.setEnabledState(!wifiService.enabled);
  }

  function toggleBluetoothEnabled() {
    bluetoothService.toggleEnabled();
  }

  function recoverKeyboard() {
    if (keyboardRecoveryBusy) return;

    keyboardRecoveryBusy = true;
    keyboardRecoveryFailed = false;
    keyboardRecoveryMessage = "";
    keyboardRecoveryProcess.exec(["/home/m4rw3r/.local/bin/recover-z13-keyboard.sh"]);
  }

  function toggleOnScreenKeyboard() {
    if (onScreenKeyboardBusy) return;

    onScreenKeyboardBusy = true;
    onScreenKeyboardFailed = false;
    onScreenKeyboardMessage = "";
    onScreenKeyboardProcess.exec([
      "sh",
      "-lc",
      "if systemctl --user is-active --quiet on-screen-keyboard.service; then pkill -RTMIN sysboard && printf 'toggled\\n'; else systemctl --user start on-screen-keyboard.service && printf 'started\\n'; fi"
    ]);
  }

  onPanelOpenChanged: {
    if (panelOpen) {
      forceActiveFocus();
      initialLoadDeadlineElapsed = false;
      initialLoadDeadline.restart();
      refreshPanelData();
      panelRefreshTimer.restart();
    } else {
      initialLoadDeadline.stop();
      initialLoadDeadlineElapsed = false;
      expandedSection = "";
      notificationReturnSection = "";
      pendingPowerAction = "";
      wifiPasswordTarget = "";
      wifiPassword = "";
      onScreenKeyboardMessage = "";
      onScreenKeyboardFailed = false;
      keyboardRecoveryMessage = "";
      keyboardRecoveryFailed = false;
      bluetoothService.stopDiscovery();
    }
  }

  Keys.onEscapePressed: {
    if (overlayDismissActive) dismissOverlaySection();
    else root.closeRequested();
  }

  Timer {
    id: powerConfirmTimer
    interval: 2200
    repeat: false
    onTriggered: root.pendingPowerAction = ""
  }

  Timer {
    id: notificationReadTimer
    interval: 350
    repeat: false
    onTriggered: {
      if (root.notificationsOpen && root.notificationCenter) root.notificationCenter.markAllRead();
    }
  }

  Timer {
    id: initialLoadDeadline
    interval: root.initialLoadDeadlineMs
    repeat: false
    onTriggered: root.initialLoadDeadlineElapsed = true
  }

  Timer {
    id: panelRefreshTimer
    interval: 180
    repeat: false
    onTriggered: root.refreshPanelData()
  }

  Services.BrightnessService {
    id: brightnessService

    onScreenPercentChanged: {
      if (!brightnessCommitTimer.running) root.pendingScreenBrightness = screenPercent;
    }
  }

  Services.LightingService {
    id: lightingService
  }

  Services.AudioService {
    id: audioService

    onVolumeChanged: {
      if (!audioCommitTimer.running) root.pendingAudioVolume = volume;
    }
  }

  Services.WifiService {
    id: wifiService

    onConnectedSsidChanged: {
      root.wifiPasswordTarget = "";
      root.wifiPassword = "";
    }
  }

  Services.BluetoothService {
    id: bluetoothService

    adapterKey: root.bluetoothAdapterKey
  }

  StdioCollector {
    id: powerProfileWriteStderr
    waitForEnd: true
  }

  Process {
    id: powerProfileWriteProcess

    stderr: powerProfileWriteStderr

    Component.onCompleted: exited.connect(function(exitCode) {

      root.powerProfileBusy = false;
    })
  }

  StdioCollector {
    id: onScreenKeyboardStdout
    waitForEnd: true
  }

  StdioCollector {
    id: onScreenKeyboardStderr
    waitForEnd: true
  }

  Process {
    id: onScreenKeyboardProcess

    stdout: onScreenKeyboardStdout
    stderr: onScreenKeyboardStderr

    Component.onCompleted: exited.connect(function(exitCode) {

      const action = String(onScreenKeyboardStdout.text || "").trim();
      root.onScreenKeyboardBusy = false;
      root.onScreenKeyboardFailed = exitCode !== 0;
      root.onScreenKeyboardMessage = exitCode === 0
        ? (action === "started" ? "On-screen keyboard started." : "On-screen keyboard toggled.")
        : (String(onScreenKeyboardStderr.text || "").trim() || "Unable to control the on-screen keyboard.");
    })
  }

  StdioCollector {
    id: keyboardRecoveryStderr
    waitForEnd: true
  }

  Process {
    id: keyboardRecoveryProcess

    stderr: keyboardRecoveryStderr

    Component.onCompleted: exited.connect(function(exitCode) {

      root.keyboardRecoveryBusy = false;
      root.keyboardRecoveryFailed = exitCode !== 0;
      root.keyboardRecoveryMessage = exitCode === 0
        ? "Keyboard recovery complete."
        : (String(keyboardRecoveryStderr.text || "").trim() || "Unable to recover the detachable keyboard.");

      brightnessService.refresh();
      lightingService.refresh();
    })
  }

  Timer {
    id: audioCommitTimer
    interval: 75
    repeat: false
    onTriggered: audioService.setVolume(root.pendingAudioVolume)
  }

  Timer {
    id: brightnessCommitTimer
    interval: 90
    repeat: false
    onTriggered: brightnessService.applyScreenPercent(root.pendingScreenBrightness)
  }

  UiSurface {
    id: panel

    width: root.implicitWidth
    implicitHeight: content.implicitHeight + Theme.insetMd * 2
    tone: "panelOverlay"
    outlined: false
    radius: Theme.radiusLg

    border.width: Theme.stroke
    border.color: Qt.rgba(1, 1, 1, 0.12)

    MouseArea {
      anchors.fill: parent
    }

    Column {
      id: content

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: Theme.insetMd
      anchors.rightMargin: Theme.insetMd
      anchors.top: parent.top
      anchors.topMargin: Theme.insetMd
      spacing: Theme.gapSm

      Row {
        width: parent.width
        height: Theme.controlSm
        spacing: Theme.gapXs

        Controls.StatusChip {
          id: batteryChip
          visible: root.batteryAvailable
          anchors.verticalCenter: parent.verticalCenter
          iconName: root.batteryIconName()
          text: root.batterySummary()
        }

        Item {
          width: Math.max(
            0,
            parent.width - (batteryChip.visible ? batteryChip.implicitWidth : 0)
            - onScreenKeyboardButton.implicitWidth - trayToggleButton.implicitWidth - powerToggleButton.implicitWidth
            - Theme.gapXs * (3 + (batteryChip.visible ? 1 : 0))
          )
          height: parent.height
        }

        Controls.IconButton {
          id: onScreenKeyboardButton
          anchors.verticalCenter: parent.verticalCenter
          iconSize: Theme.iconGlyphSm
          circular: true
          iconName: "keyboard"
          active: root.onScreenKeyboardBusy || root.keyboardRecoveryBusy
          enabled: !root.onScreenKeyboardBusy && !root.keyboardRecoveryBusy
          pressAndHoldInterval: 700
          onClicked: root.toggleOnScreenKeyboard()
          onPressAndHold: root.recoverKeyboard()
        }

        Controls.IconButton {
          id: trayToggleButton
          anchors.verticalCenter: parent.verticalCenter
          iconSize: Theme.iconGlyphSm
          circular: true
          iconName: root.trayExpanded ? "panel-right-open" : "panel-right"
          active: root.trayExpanded
          onClicked: root.trayToggleRequested()

          Rectangle {
            visible: root.trayNeedsAttention
            width: 10
            height: 10
            radius: 5
            color: Theme.accentStrong
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 3
            anchors.rightMargin: 3
            border.width: 1
            border.color: Theme.panelOverlay
          }
        }

        Controls.IconButton {
          id: powerToggleButton
          anchors.verticalCenter: parent.verticalCenter
          iconSize: Theme.iconGlyphSm
          circular: true
          iconName: "power"
          active: root.expandedSection === "power"
          enabled: !root.sessionActionBusy
          onClicked: root.toggleSection("power")
        }
      }

      UiText {
        width: parent.width
        visible: root.onScreenKeyboardMessage !== ""
        text: root.onScreenKeyboardMessage
        size: "xs"
        tone: root.onScreenKeyboardFailed ? "accent" : "subtle"
        wrapMode: Text.WordWrap
      }

      UiText {
        width: parent.width
        visible: root.keyboardRecoveryMessage !== ""
        text: root.keyboardRecoveryMessage
        size: "xs"
        tone: root.keyboardRecoveryFailed ? "accent" : "subtle"
        wrapMode: Text.WordWrap
      }

      Controls.HeroClock {
        width: parent.width
      }

      Item {
        id: powerPopoverSpacer

        width: parent.width
        height: root.powerMenuOpen ? powerPopover.implicitHeight : 0
      }

      Row {
        width: parent.width
        height: Theme.controlSm
        spacing: 0

        Controls.Slider {
          width: parent.width
          anchors.verticalCenter: parent.verticalCenter
          showIcon: false
          trailingSlotWidth: Theme.controlAccessorySlot - Theme.nudge
          leadingAccessory: [
            Controls.IconButton {
              anchors.centerIn: parent
              width: implicitWidth
              variant: "minimal"
              iconName: root.audioReady && audioService.muted ? "speaker-muted" : "speaker"
              active: root.audioReady && audioService.muted
              enabled: root.audioReady
              onClicked: {
                if (root.audioReady) audioService.toggleMuted();
              }
            }
          ]
          trailingAccessory: [
            Controls.IconButton {
              anchors.centerIn: parent
              width: implicitWidth
              variant: "minimal"
              iconSize: Theme.iconGlyphSm
              iconName: root.expandedSection === "outputs" ? "chevron-down" : "chevron-right"
              active: root.expandedSection === "outputs"
              enabled: Pipewire.ready
              onClicked: root.toggleSection("outputs")
            }
          ]
          value: root.pendingAudioVolume
          enabled: root.audioReady
          onValueMoved: function(value) {
            if (!root.audioReady) return;
            root.pendingAudioVolume = value;
            audioCommitTimer.restart();
          }
          onValueCommitted: function(value) {
            if (!root.audioReady) return;
            root.pendingAudioVolume = value;
            audioCommitTimer.stop();
            audioService.setVolume(value);
          }
        }
      }

      UiText {
        visible: root.audioLoading && root.initialLoadDeadlineElapsed
        text: "Loading audio..."
        size: "xs"
        tone: "subtle"
      }

      UiText {
        visible: audioService.settled && !root.audioReady && !root.audioLoading
        text: audioService.lastError !== "" ? audioService.lastError : "Audio unavailable."
        size: "xs"
        tone: "accent"
        wrapMode: Text.WordWrap
      }

      Item {
        id: outputsPopoverSpacer

        width: parent.width
        height: root.outputMenuOpen ? outputsPopover.implicitHeight : 0
      }

      Row {
        width: parent.width
        height: Theme.controlSm
        spacing: 0

        Controls.Slider {
          id: brightnessSlider

          width: parent.width
          anchors.verticalCenter: parent.verticalCenter
          showIcon: false
          trailingSlotWidth: Theme.controlAccessorySlot - Theme.nudge
          leadingAccessory: [
            Controls.IconButton {
              anchors.centerIn: parent
              interactive: false
              variant: "minimal"
              iconName: "sun"
            }
          ]
          from: 0
          to: 100
          value: brightnessService.screenPercent
          enabled: brightnessService.screenAvailable
          onValueMoved: function(value) {
            root.pendingScreenBrightness = value;
            brightnessCommitTimer.restart();
          }
          onValueCommitted: function(value) {
            root.pendingScreenBrightness = value;
            brightnessCommitTimer.stop();
            brightnessService.applyScreenPercent(value);
          }
        }
      }

      UiText {
        visible: root.brightnessLoading && root.initialLoadDeadlineElapsed
        text: "Loading brightness..."
        size: "xs"
        tone: "subtle"
      }

      UiText {
        visible: brightnessService.settled && brightnessService.lastError === "" && !brightnessService.screenAvailable
        text: "No brightness device detected."
        size: "xs"
        tone: "subtle"
      }

      UiText {
        visible: brightnessService.lastError !== "" && !root.brightnessLoading
        text: brightnessService.lastError
        size: "xs"
        tone: "accent"
        wrapMode: Text.WordWrap
      }

      Column {
        id: quickTileStack

        width: parent.width
        spacing: 8

        Item {
          id: quickTileSection

          width: parent.width
          height: root.expandedSection === "wifi"
            ? wifiMenuPanel.implicitHeight
            : (root.expandedSection === "bluetooth" ? bluetoothMenuPanel.implicitHeight : quickTileRow.implicitHeight)

          Row {
            id: quickTileRow

            visible: !root.tileMenuOpen
            width: parent.width
            spacing: 8

            Patterns.QuickToggleMenuTile {
              id: wifiTile

              width: Math.floor((parent.width - parent.spacing) / 2)
              iconName: "wifi"
              title: root.wifiTileTitle()
              active: wifiService.ready && wifiService.enabled
              menuOpen: root.expandedSection === "wifi"
              enabled: wifiService.ready && !root.tileMenuOpen
              onPrimaryClicked: root.toggleWifiEnabled()
              onSecondaryClicked: root.toggleSection("wifi")
            }

            Patterns.QuickToggleMenuTile {
              id: bluetoothTile

              width: Math.floor((parent.width - parent.spacing) / 2)
              iconName: "bluetooth"
              title: root.bluetoothTileTitle()
              active: bluetoothService.enabled
              menuOpen: root.expandedSection === "bluetooth"
              enabled: !root.tileMenuOpen
              onPrimaryClicked: root.toggleBluetoothEnabled()
              onSecondaryClicked: root.toggleSection("bluetooth")
            }
          }
        }

        Item {
          id: profileSection

          width: parent.width
          height: profileRow.height

          Row {
            id: profileRow

            width: parent.width
            spacing: 8

            Patterns.QuickSelectorTile {
              id: profileTile
              width: lightingService.commandAvailable ? Math.floor((parent.width - parent.spacing) / 2) : parent.width
              iconName: "gauge"
              title: root.profileShortLabel()
              useActiveStyling: false
              open: root.expandedSection === "profile"
              onClicked: root.toggleSection("profile")
            }

            Patterns.QuickSelectorTile {
              id: lightingTile
              visible: lightingService.commandAvailable
              width: Math.floor((parent.width - parent.spacing) / 2)
              iconName: "sun"
              title: root.lightingTileTitle()
              active: lightingService.available && root.lightingLevelIndex() > 0
              enabled: lightingService.commandAvailable
              useActiveStyling: true
              open: root.expandedSection === "lighting"
              onClicked: root.toggleSection("lighting")
            }
          }

        }
      }

      Item {
        id: notificationSection

        width: parent.width
        height: root.notificationsOpen ? notificationMenuPanel.implicitHeight : notificationsFooter.implicitHeight

        Item {
          id: notificationsFooter

          visible: !root.notificationsOpen
          width: parent.width
          implicitHeight: Theme.tileHeight

          readonly property bool pressed: notificationFooterTouchArea.pressed

          Patterns.QuickTileFrame {
            anchors.fill: parent
            iconName: root.unreadNotificationCount > 0 ? "bell-dot" : "bell"
            title: ""
            backgroundColor: notificationsFooter.pressed ? Theme.fieldPressed : Theme.field
            borderColor: Qt.rgba(1, 1, 1, 0.08)
            iconColor: Theme.text
            textTone: "primary"
            trailingWidth: Theme.iconGlyphSm

            UiIcon {
              anchors.centerIn: parent
              width: Theme.iconGlyphSm
              height: Theme.iconGlyphSm
              name: "chevron-right"
              strokeColor: Theme.textSubtle
            }
          }

          Column {
            anchors.left: parent.left
            anchors.leftMargin: Theme.gapSm + Theme.iconGlyphSm + Theme.gapXs
            anchors.right: parent.right
            anchors.rightMargin: Theme.gapSm + Theme.iconGlyphSm + Theme.gapXs
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.nudge

            Item {
              width: parent.width
              height: sourceLabel.implicitHeight

              UiText {
                id: sourceLabel

                anchors.left: parent.left
                anchors.right: unreadBadge.left
                anchors.rightMargin: unreadBadge.visible ? Theme.gapXs : 0
                anchors.verticalCenter: parent.verticalCenter
                text: root.footerNotificationEntry && root.notificationCenter
                  ? root.notificationCenter.appLabel(root.footerNotificationEntry)
                  : "Notifications"
                size: "xs"
                tone: root.notificationCount > 0 ? "primary" : "muted"
                font.weight: Font.DemiBold
                elide: Text.ElideRight
              }

              Rectangle {
                id: unreadBadge

                visible: root.unreadNotificationCount > 0
                width: visible ? Math.max(Theme.iconGlyphMd, unreadBadgeLabel.implicitWidth + Theme.gapSm) : 0
                height: visible ? Theme.iconGlyphMd : 0
                radius: height / 2
                color: root.notificationsCriticalUnread ? Theme.accent : Theme.toggleOn
                anchors.right: parent.right
                y: Math.round((notificationsFooter.height - height) / 2) - 7

                UiText {
                  id: unreadBadgeLabel

                  anchors.centerIn: parent
                  text: root.unreadNotificationCount > 99 ? "99+" : String(root.unreadNotificationCount)
                  size: "xs"
                  tone: "onAccent"
                  font.weight: Font.DemiBold
                }
              }
            }

            UiText {
              width: parent.width
              text: root.footerNotificationEntry && root.notificationCenter
                ? root.notificationCenter.summaryLabel(root.footerNotificationEntry)
                : "No notifications"
              size: "sm"
              tone: root.notificationCount > 0 ? "primary" : "subtle"
              elide: Text.ElideRight
              textFormat: Text.PlainText
            }
          }

          Rectangle {
            visible: root.notificationsCriticalUnread
            width: 8
            height: 8
            radius: 4
            color: Theme.accentStrong
            x: Theme.gapSm + Theme.iconGlyphSm - width * 0.35
            y: Math.round((parent.height - Theme.iconGlyphSm) / 2) - height * 0.25
          }

          MouseArea {
            id: notificationFooterTouchArea

            anchors.fill: parent
            onClicked: root.toggleNotificationsSection()
          }
        }
      }

    }

    UiScrim {
      anchors.fill: parent
      radius: panel.radius
      visible: root.overlayDismissActive
      z: 3
    }

    Item {
      id: tileMenuOverlay

      anchors.fill: parent
      visible: root.overlayDismissActive
      z: 4

      MouseArea {
        anchors.fill: parent
        enabled: root.overlayDismissActive
        onClicked: root.dismissOverlaySection()
      }

      ControlCenterParts.NotificationsPopover {
        id: notificationMenuPanel

        controller: root
        width: content.width
        x: content.x
        y: content.y + notificationSection.y
        z: 1
      }

      Patterns.HeroSheetPopover {
        id: outputsPopover

        visible: root.outputMenuOpen
        width: content.width
        x: content.x
        y: content.y + outputsPopoverSpacer.y
        z: 1
        iconName: root.audioReady && audioService.muted ? "speaker-muted" : "speaker"
        title: root.outputMenuTitle()
        subtitle: root.outputMenuSubtitle()
        hasStatus: root.audioReady
        statusActive: root.audioReady && !audioService.muted
        statusToggleEnabled: root.audioReady
        onStatusClicked: audioService.toggleMuted()

        Column {
          width: parent.width
          spacing: 8

          UiText {
            visible: audioService.settled && !root.audioReady && !root.audioLoading
            text: audioService.lastError !== "" ? audioService.lastError : "Audio unavailable."
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
                title: root.outputLabel(outputRow.outputNode)
                trailingIconName: root.audioSink === outputRow.outputNode ? "check" : ""
                trailingIconColor: Theme.text
                active: root.audioSink === outputRow.outputNode
                enabled: shown
                onClicked: Pipewire.preferredDefaultAudioSink = outputRow.outputNode
              }
            }
          }
        }
      }

      Patterns.HeroSheetPopover {
        id: powerPopover

        visible: root.powerMenuOpen
        width: content.width
        x: content.x
        y: content.y + powerPopoverSpacer.y
        z: 1
        iconName: root.powerActionIcon(root.powerHeroAction())
        title: root.powerActionTitle(root.powerHeroAction())
        subtitle: root.powerHeroHint()

        Column {
          width: parent.width
          spacing: 4

          Column {
            width: parent.width
            spacing: 2

            Repeater {
              model: root.powerMenuEntries

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
                  actionText: !!parent.entry.confirm && root.pendingPowerAction === parent.entry.action ? "Confirm" : ""
                  active: !!parent.entry.confirm && root.pendingPowerAction === parent.entry.action
                  enabled: !root.sessionActionBusy
                  onClicked: {
                    if (parent.entry.confirm) root.triggerPowerAction(parent.entry.action);
                    else root.runSessionAction(parent.entry.action);
                  }
                }
              }
            }
          }
        }
      }

      ControlCenterParts.WifiPopover {
        id: wifiMenuPanel

        controller: root
        wifiService: wifiService
        width: content.width
        x: content.x
        y: content.y + quickTileStack.y + quickTileSection.y
        z: 1
      }

      Patterns.HeroSheetPopover {
        id: bluetoothMenuPanel

        visible: root.expandedSection === "bluetooth"
        width: content.width
        sectionSpacing: Theme.gapSm
        x: content.x
        y: content.y + quickTileStack.y + quickTileSection.y
        z: 1
        iconName: "bluetooth"
        title: root.bluetoothTileTitle()
        subtitle: root.bluetoothTileSubtitle()
        hasStatus: !!bluetoothService.adapter
        statusActive: !!(bluetoothService.adapter && bluetoothService.enabled && !bluetoothService.blocked)
        statusBusy: bluetoothService.busy
        statusToggleEnabled: !!bluetoothService.adapter && !bluetoothService.hardBlocked
        onStatusClicked: root.toggleBluetoothEnabled()

        Column {
          width: parent.width
          spacing: Theme.gapSm

          Column {
            width: parent.width
            spacing: Theme.gapXs
            visible: !bluetoothService.adapter || root.bluetoothBlockedMessage() !== "" || bluetoothService.lastError !== ""

            UiText {
              visible: !bluetoothService.adapter
              text: "No Bluetooth adapter found."
              size: "xs"
              tone: "accent"
            }

            UiText {
              visible: root.bluetoothBlockedMessage() !== ""
              text: root.bluetoothBlockedMessage()
              size: "xs"
              tone: "accent"
              wrapMode: Text.WordWrap
            }

            UiText {
              visible: bluetoothService.lastError !== ""
              text: bluetoothService.lastError
              size: "xs"
              tone: "accent"
              wrapMode: Text.WordWrap
            }
          }

          Column {
            width: parent.width
            spacing: 4
            visible: bluetoothService.enabled && bluetoothService.connectedCount > 0

            UiText {
              text: "Connected Devices"
              size: "xs"
              tone: "muted"
              font.weight: Font.DemiBold
            }

            Column {
              width: parent.width
              spacing: 4

              Repeater {
                model: bluetoothService.enabled ? bluetoothService.devices : []

                delegate: Controls.PopoverMenuAction {
                  id: connectedDeviceRow

                  required property var modelData
                  readonly property var device: modelData
                  readonly property bool busyState: !!(device && (device.pairing || device.state === BluetoothDeviceState.Connecting))

                  visible: !!(device && device.connected)
                  width: parent.width
                  title: root.bluetoothDeviceTitle(device)
                  subtitle: root.bluetoothConnectedSubtitle(device)
                  actionText: busyState ? "Working" : "Disconnect"
                  active: true
                  enabled: visible && !busyState
                  onClicked: {
                    if (busyState) return;
                    device.disconnect();
                  }
                }
              }
            }
          }

          Column {
            width: parent.width
            spacing: 4
            visible: bluetoothService.enabled && bluetoothService.availableCount > 0

            readonly property real scrollIndicatorHeight: Theme.iconGlyphSm
            readonly property bool scanListOverflowing: bluetoothScanViewport.contentHeight > bluetoothScanViewport.height + 1
            readonly property bool scanListHasMoreAbove: scanListOverflowing && bluetoothScanViewport.contentY > 1
            readonly property bool scanListHasMoreBelow: scanListOverflowing
              && bluetoothScanViewport.contentY + bluetoothScanViewport.height < bluetoothScanViewport.contentHeight - 1

            UiText {
              text: "Available Devices"
              size: "xs"
              tone: "muted"
              font.weight: Font.DemiBold
            }

            Item {
              width: parent.width
              height: parent.scrollIndicatorHeight

              UiIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.height
                height: parent.height
                name: "chevron-up"
                strokeColor: Theme.textSubtle
                opacity: parent.parent.scanListHasMoreAbove ? 0.8 : 0
              }
            }

            Flickable {
              id: bluetoothScanViewport

              width: parent.width
              height: Math.min(bluetoothScanContent.implicitHeight, root.bluetoothScanViewportMaxHeight)
              clip: true
              contentWidth: width
              contentHeight: bluetoothScanContent.implicitHeight
              boundsBehavior: Flickable.StopAtBounds

              ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
              }

              Column {
                id: bluetoothScanContent

                width: bluetoothScanViewport.width
                spacing: 4

                Repeater {
                  model: bluetoothService.enabled ? bluetoothService.devices : []

                  delegate: Controls.PopoverMenuAction {
                    id: otherDeviceRow

                    required property var modelData
                    readonly property var device: modelData
                    readonly property bool busyState: !!(device && (device.pairing || device.state === BluetoothDeviceState.Connecting))

                    visible: !!(device && !device.connected)
                    width: parent.width
                    title: root.bluetoothDeviceTitle(device)
                    subtitle: root.bluetoothAvailableSubtitle(device)
                    actionText: busyState ? "Working" : (device && (device.paired || device.bonded) ? "Connect" : "Pair")
                    enabled: visible && !busyState
                    onClicked: {
                      if (busyState) return;
                      if (device.paired || device.bonded) device.connect();
                      else device.pair();
                    }
                  }
                }
              }
            }

            Item {
              width: parent.width
              height: parent.scrollIndicatorHeight

              UiIcon {
                id: chevronIndicator

                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.height
                height: parent.height
                name: "chevron-down"
                strokeColor: Theme.textSubtle
                opacity: parent.parent.scanListHasMoreBelow ? 0.8 : 0
              }
            }
          }

          Column {
            width: parent.width
            spacing: 4

            Controls.Divider {}

            Controls.PopoverMenuAction {
              width: parent.width
              title: root.bluetoothPrimaryActionText()
              enabled: !!bluetoothService.adapter && !bluetoothService.busy && !bluetoothService.hardBlocked
              onClicked: root.toggleBluetoothEnabled()
            }

            Controls.PopoverMenuAction {
              width: parent.width
              title: bluetoothService.discovering ? "Stop Scan" : "Scan"
              enabled: !!bluetoothService.adapter && bluetoothService.enabled && !bluetoothService.busy
              onClicked: {
                bluetoothService.setDiscoveryEnabled(!bluetoothService.discovering);
              }
            }
          }
        }
      }
    }

    Item {
      id: popoverLayer

      anchors.fill: parent
      z: 6

      MouseArea {
        anchors.fill: parent
        enabled: root.selectorPopoverOpen
        onClicked: root.dismissOverlaySection()
      }

      Controls.PopoverSurface {
        id: profilePopover
        visible: root.expandedSection === "profile"
        width: implicitWidth
        x: root.popupX(profileTile, width, false)
        y: root.popupOverlayY(profileTile, height)

        Repeater {
          model: root.profileOptions

          delegate: Controls.MenuItem {
            required property var modelData
            readonly property var option: modelData

            width: parent.width
            iconName: "gauge"
            title: option.title
            trailingIconName: PowerProfiles.profile === option.profile ? "check" : ""
            active: PowerProfiles.profile === option.profile
            activeStyle: "indicator"
            compact: true
            dividerVisible: option.dividerVisible
            enabled: option.enabled && !root.powerProfileBusy
            onClicked: root.selectPowerProfile(option.profile)
          }
        }
      }

      Controls.PopoverSurface {
        visible: root.expandedSection === "lighting" && lightingService.commandAvailable
        width: lightingTile.width
        x: root.popupX(lightingTile, width, false)
        y: root.popupOverlayY(lightingTile, height)

        Repeater {
          model: root.lightingOptions

          delegate: Controls.MenuItem {
            required property var modelData
            readonly property var option: modelData

            width: parent.width
            iconName: "sun"
            title: option.title
            trailingIconName: root.lightingLevelIndex() === option.index ? "check" : ""
            active: root.lightingLevelIndex() === option.index
            activeStyle: "indicator"
            compact: true
            dividerVisible: option.dividerVisible
            onClicked: root.setLightingLevel(option.index)
          }
        }

      }

    }
  }
}
