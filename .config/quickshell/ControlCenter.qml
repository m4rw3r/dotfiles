pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import "services" as Services
import "controlcenter" as ControlCenterParts
import "theme"
import "ui/primitives"
import "ui/controls" as Controls
import "ui/patterns" as Patterns

FocusScope {
  id: root

  signal closeRequested
  signal trayToggleRequested

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
  property string powerProfileError: ""
  property real pendingAudioVolume: 0
  property real pendingScreenBrightness: 0
  property bool panelOpen: false
  property bool trayVisible: false
  property bool trayExpanded: false
  property bool trayNeedsAttention: false
  property var popupParentWindow: null
  property bool popupDismissInProgress: false
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
  readonly property real notificationViewportMaxHeight: Math.max(Theme.controlMd * 4, Math.min(Theme.controlMd * 8, parent ? parent.height * 0.36 : Theme.controlMd * 6))
  readonly property int bluetoothScanVisibleRowCount: 6
  readonly property real bluetoothScanViewportMaxHeight: Theme.controlMd * bluetoothScanVisibleRowCount + 4 * (bluetoothScanVisibleRowCount - 1)
  readonly property bool powerMenuOpen: expandedSection === "power"
  readonly property bool outputMenuOpen: expandedSection === "outputs"
  readonly property bool selectorPopoverOpen: expandedSection === "profile" || (expandedSection === "lighting" && lightingService.commandAvailable)
  readonly property bool tileMenuOpen: expandedSection === "wifi" || expandedSection === "bluetooth"
  readonly property bool overlayDismissActive: selectorPopoverOpen || tileMenuOpen || powerMenuOpen || outputMenuOpen || notificationsOpen
  property var audioSink: null
  readonly property var audioState: audioSink && audioSink.audio ? audioSink.audio : null
  readonly property var battery: UPower.displayDevice
  readonly property bool batteryAvailable: battery && battery.isPresent && battery.isLaptopBattery
  readonly property bool audioReady: Pipewire.ready && !!audioSink && audioSink.ready && !!audioState
  readonly property bool audioLoading: panelOpen && (!Pipewire.ready || (!!audioSink && !audioSink.ready))
  readonly property bool brightnessLoading: panelOpen && !brightnessService.settled
  readonly property bool wifiLoading: panelOpen && !wifiService.ready
  readonly property var powerMenuEntries: [
    {
      kind: "action",
      title: "Lock",
      action: "lock",
      confirm: false
    },
    {
      kind: "action",
      title: "Suspend",
      action: "sleep",
      confirm: false
    },
    {
      kind: "action",
      title: "Restart",
      action: "restart",
      confirm: true
    },
    {
      kind: "action",
      title: "Power Off",
      action: "shutdown",
      confirm: true
    },
    {
      kind: "divider"
    },
    {
      kind: "action",
      title: "Log Out",
      action: "logout",
      confirm: true
    }
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
    {
      title: "Off",
      index: 0,
      dividerVisible: true
    },
    {
      title: "Low",
      index: 1,
      dividerVisible: true
    },
    {
      title: "Medium",
      index: 2,
      dividerVisible: true
    },
    {
      title: "High",
      index: 3,
      dividerVisible: false
    }
  ]

  Component.onCompleted: {
    refreshPanelData();
    panelRefreshTimer.restart();
  }
  onAudioSinkChanged: {
    audioCommitTimer.stop();
    syncPendingAudioVolume();
  }
  onAudioStateChanged: {
    audioCommitTimer.stop();
    syncPendingAudioVolume();
  }
  onNotificationsOpenChanged: {
    if (notificationsOpen) {
      syncExpandedNotificationGroups();
      if (unreadNotificationCount > 0)
        notificationReadTimer.restart();
      else
        notificationReadTimer.stop();
      return;
    }

    notificationReadTimer.stop();
  }
  onNotificationCountChanged: syncExpandedNotificationGroups()
  onNotificationCenterChanged: syncExpandedNotificationGroups()

  function clamp(value, minValue, maxValue) {
    return Math.max(minValue, Math.min(maxValue, value));
  }

  function withAlpha(color, alpha) {
    return Qt.rgba(color.r, color.g, color.b, alpha);
  }

  function setExpandedSection(section) {
    if (expandedSection === "notifications" && section !== "notifications")
      notificationReturnSection = "";

    expandedSection = section;
    if (expandedSection !== "wifi") {
      wifiPasswordTarget = "";
      wifiPassword = "";
    }
    if (expandedSection !== "power")
      pendingPowerAction = "";
    if (expandedSection === "wifi")
      wifiService.refresh();
    if (expandedSection !== "bluetooth")
      bluetoothService.stopDiscovery();
  }

  function openSection(section) {
    setExpandedSection(section);
  }

  function closeSection(section) {
    if (expandedSection === section)
      setExpandedSection("");
  }

  function closeExpandedSectionIfCurrent(section) {
    if (expandedSection === section)
      setExpandedSection("");
  }

  function popupDismissed(section) {
    popupDismissInProgress = true;
    closeExpandedSectionIfCurrent(section);
    Qt.callLater(function () {
      popupDismissInProgress = false;
    });
  }

  function toggleSection(section) {
    setExpandedSection(expandedSection === section ? "" : section);
  }

  function closeCurrentSection() {
    setExpandedSection("");
  }

  function returnFromNotifications() {
    const returnSection = notificationReturnSection;
    notificationReturnSection = "";
    setExpandedSection(returnSection);
  }

  function toggleNotificationsSection() {
    if (notificationsOpen) {
      returnFromNotifications();
      return;
    }

    notificationReturnSection = expandedSection === "notifications" ? "" : expandedSection;
    setExpandedSection("notifications");
  }

  function syncExpandedNotificationGroups() {
    const currentState = expandedNotificationGroups || {};
    const currentKeys = Object.keys(currentState);
    if (currentKeys.length === 0)
      return;

    const groups = notificationCenter ? notificationCenter.groupedEntries : [];
    if (!groups || groups.length === 0) {
      expandedNotificationGroups = ({});
      return;
    }

    const validKeys = {};
    for (let index = 0; index < groups.length; index += 1) {
      const group = groups[index];
      if (group && group.key !== undefined)
        validKeys[group.key] = true;
    }

    const nextState = {};
    let changed = false;
    for (let index = 0; index < currentKeys.length; index += 1) {
      const key = currentKeys[index];
      if (validKeys[key])
        nextState[key] = currentState[key];
      else
        changed = true;
    }

    if (changed)
      expandedNotificationGroups = nextState;
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
    if (notificationCenter)
      notificationCenter.forgetGroup(groupKey);

    const nextState = Object.assign({}, expandedNotificationGroups);
    delete nextState[groupKey];
    expandedNotificationGroups = nextState;
  }

  function dismissOverlaySection() {
    if (!overlayDismissActive)
      return;
    if (notificationsOpen) {
      toggleNotificationsSection();
      return;
    }

    closeCurrentSection();
  }

  function batterySummary() {
    if (!batteryAvailable)
      return "N/A";

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
    if (!batteryAvailable)
      return "battery";

    const state = battery.state;
    if (state === UPowerDeviceState.Charging || state === UPowerDeviceState.PendingCharge)
      return "battery-charging";
    return "battery";
  }

  function normalizePowerAction(action) {
    if (action === "sleep")
      return "suspend";
    return action;
  }

  function powerActionTitle(action) {
    if (action === "lock")
      return "Lock";
    if (action === "suspend" || action === "sleep")
      return "Suspend";
    if (action === "restart")
      return "Restart";
    if (action === "logout")
      return "Log Out";
    return "Power Off";
  }

  function powerActionIcon(action) {
    if (action === "lock")
      return "lock";
    if (action === "suspend" || action === "sleep")
      return "moon";
    if (action === "restart")
      return "restart";
    if (action === "logout")
      return "logout";
    return "power";
  }

  function powerHeroAction() {
    if (sessionActionBusy)
      return normalizePowerAction(sessionActions.busyAction);
    return pendingPowerAction !== "" ? pendingPowerAction : "shutdown";
  }

  function powerHeroHint() {
    if (sessionActionBusy)
      return `${powerActionTitle(sessionActions.busyAction)} in progress...`;
    if (pendingPowerAction !== "")
      return "Press the highlighted action again to confirm";
    return "";
  }

  function wifiTileTitle() {
    if (!wifiService.ready)
      return "Wi-Fi";
    if (!wifiService.enabled || wifiService.connectedSsid === "")
      return "Wi-Fi";
    return wifiService.connectedSsid;
  }

  function wifiHeroHint() {
    if (!wifiService.ready)
      return initialLoadDeadlineElapsed ? "Loading Wi-Fi..." : "";
    if (wifiService.lastError !== "")
      return "Unavailable";
    if (!wifiService.hardwareEnabled)
      return "Wi-Fi hardware is blocked.";
    if (!wifiService.enabled)
      return "Wi-Fi is off";
    if (wifiService.connectedSsid !== "")
      return `${wifiService.connectedSignal}% signal`;
    if (wifiService.networks.length > 0)
      return `${wifiService.networks.length} networks available`;
    return "No networks available";
  }

  function wifiNetworkSubtitle(network) {
    if (!network)
      return "";

    const securityLabel = network.security !== "" ? network.security : "open";
    const savedLabel = network.known ? ", saved" : "";
    return `${network.signal}%, ${securityLabel}${savedLabel}`;
  }

  function bluetoothTileTitle() {
    const count = bluetoothService.connectedCount;
    if (count > 0)
      return count === 1 ? "1 Device" : `${count} Devices`;
    return "Bluetooth";
  }

  function bluetoothTileSubtitle() {
    if (!bluetoothService.adapter)
      return "Unavailable";
    if (bluetoothService.busy)
      return "Unblocking...";
    if (bluetoothService.hardBlocked)
      return "Hardware Blocked";
    if (bluetoothService.blocked)
      return bluetoothService.blockStateKnown ? "Blocked" : "Checking Block";
    if (!bluetoothService.enabled)
      return "Off";
    return bluetoothService.discovering ? "Scanning" : "Ready";
  }

  function bluetoothDeviceText(value) {
    return String(value || "").trim();
  }

  function isBluetoothIdentifier(value) {
    return /^([0-9A-F]{2}[:-]){5}[0-9A-F]{2}$/i.test(bluetoothDeviceText(value));
  }

  function bluetoothDeviceTitle(device) {
    if (!device)
      return "";

    const alias = bluetoothDeviceText(device.name);
    const deviceName = bluetoothDeviceText(device.deviceName);
    const address = bluetoothDeviceText(device.address);

    if (alias !== "" && !isBluetoothIdentifier(alias))
      return alias;
    if (deviceName !== "" && !isBluetoothIdentifier(deviceName))
      return deviceName;
    if (alias !== "")
      return alias;
    if (deviceName !== "")
      return deviceName;
    return address;
  }

  function bluetoothDeviceAddressLabel(device) {
    if (!device)
      return "";

    const title = bluetoothDeviceTitle(device);
    const address = bluetoothDeviceText(device.address);
    if (address === "" || title === address)
      return "";
    return address;
  }

  function bluetoothConnectedSubtitle(device) {
    if (!device)
      return "";

    const parts = [];
    parts.push(device.batteryAvailable ? `${Math.round(device.battery * 100)}% battery` : "Connected");

    const addressLabel = bluetoothDeviceAddressLabel(device);
    if (addressLabel !== "")
      parts.push(addressLabel);
    return parts.join(" - ");
  }

  function bluetoothAvailableSubtitle(device) {
    if (!device)
      return "";

    const parts = [device.paired || device.bonded ? "Paired" : "Available"];
    const addressLabel = bluetoothDeviceAddressLabel(device);
    if (addressLabel !== "")
      parts.push(addressLabel);
    return parts.join(" - ");
  }

  function bluetoothBlockedMessage() {
    if (!bluetoothService.blocked)
      return "";
    if (bluetoothService.busy)
      return "Unblocking Bluetooth...";
    if (bluetoothService.hardBlocked)
      return "Bluetooth is blocked by hardware or firmware airplane mode.";
    if (!bluetoothService.blockStateKnown)
      return "Checking Bluetooth block state...";
    return "Bluetooth is blocked by rfkill. Unblock will try to clear it.";
  }

  function bluetoothPrimaryActionText() {
    if (bluetoothService.busy)
      return "Unblocking...";
    if (bluetoothService.hardBlocked)
      return "Blocked";
    if (bluetoothService.blocked)
      return bluetoothService.blockStateKnown ? "Unblock" : "Checking...";
    return bluetoothService.enabled ? "Turn Off" : "Turn On";
  }

  function profileShortLabel() {
    if (PowerProfiles.profile === PowerProfile.PowerSaver)
      return "Power Saver";
    if (PowerProfiles.profile === PowerProfile.Performance)
      return "Performance";
    return "Balanced";
  }

  function profileCommandValue(profile) {
    if (profile === PowerProfile.PowerSaver)
      return "quiet";
    if (profile === PowerProfile.Performance)
      return "performance";
    return "balanced";
  }

  function selectPowerProfile(profile) {
    powerProfileBusy = true;
    powerProfileError = "";
    closeCurrentSection();
    powerProfileWriteProcess.exec(["z13ctl", "profile", "--set", profileCommandValue(profile)]);
  }

  function lightingTileTitle() {
    if (lightingService.commandAvailable && !lightingService.available)
      return "Unavailable";
    return lightingLevelLabel(lightingLevelIndex());
  }

  function lightingLevelKey(index) {
    if (index === 3)
      return "high";
    if (index === 2)
      return "medium";
    if (index === 1)
      return "low";
    return "off";
  }

  function lightingLevelIndex() {
    if (lightingService.level === "high")
      return 3;
    if (lightingService.level === "medium")
      return 2;
    if (lightingService.level === "low")
      return 1;
    return 0;
  }

  function lightingLevelLabel(index) {
    if (index === 3)
      return "High";
    if (index === 2)
      return "Medium";
    if (index === 1)
      return "Low";
    return "Off";
  }

  function setLightingLevel(index) {
    if (!lightingService.available)
      return;
    closeCurrentSection();
    lightingService.applyLevel(lightingLevelKey(index));
  }

  function outputLabel(node) {
    if (!node)
      return "Unknown output";
    return node.description || node.nickname || node.name || "Unknown output";
  }

  function outputMenuTitle() {
    if (audioSink)
      return outputLabel(audioSink);
    return "Sound Output";
  }

  function outputMenuSubtitle() {
    if (!Pipewire.ready)
      return initialLoadDeadlineElapsed ? "Loading audio..." : "";
    if (!audioSink)
      return "No audio output";
    if (!audioReady)
      return "Audio unavailable";
    return audioVolumePercentText();
  }

  function audioVolumeValue() {
    if (!audioReady)
      return 0;
    return clamp(Number(audioState.volume), 0, 1);
  }

  function audioVolumePercentText() {
    if (!audioReady)
      return "Unavailable";
    if (audioState.muted)
      return "Muted";
    return `${Math.round(audioVolumeValue() * 100)}%`;
  }

  function refreshPanelData() {
    brightnessService.refresh();
    lightingService.refresh();
    wifiService.refresh();
    pendingAudioVolume = audioVolumeValue();
    pendingScreenBrightness = brightnessService.screenPercent;
  }

  function syncPendingAudioVolume() {
    if (!audioCommitTimer.running)
      pendingAudioVolume = audioVolumeValue();
  }

  function applyAudioVolume(value) {
    if (!audioReady)
      return;

    const nextVolume = clamp(Number(value), 0, 1);
    audioState.muted = false;
    audioState.volume = nextVolume;
  }

  function beginWifiConnect(network) {
    if (!network)
      return;

    wifiService.lastError = "";

    if (!network.secure || network.known) {
      wifiPasswordTarget = "";
      wifiPassword = "";
      wifiService.connectNetwork(network.ssid, "");
      return;
    }

    openSection("wifi");
    wifiPasswordTarget = network.ssid;
    wifiPassword = "";
  }

  function submitWifiPassword() {
    if (wifiPasswordTarget === "" || wifiPassword === "")
      return;
    wifiService.connectNetwork(wifiPasswordTarget, wifiPassword);
  }

  function runSessionAction(action) {
    if (!sessionActions || sessionActionBusy)
      return;

    pendingPowerAction = "";
    root.closeRequested();

    Qt.callLater(function () {
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
    if (keyboardRecoveryBusy)
      return;

    keyboardRecoveryBusy = true;
    keyboardRecoveryFailed = false;
    keyboardRecoveryMessage = "";
    keyboardRecoveryProcess.exec(["/home/m4rw3r/.local/bin/recover-z13-keyboard.sh"]);
  }

  function toggleOnScreenKeyboard() {
    if (onScreenKeyboardBusy)
      return;

    onScreenKeyboardBusy = true;
    onScreenKeyboardFailed = false;
    onScreenKeyboardMessage = "";
    onScreenKeyboardProcess.exec(["sh", "-lc", "if systemctl --user is-active --quiet on-screen-keyboard.service; then pkill -RTMIN sysboard && printf 'toggled\\n'; else systemctl --user start on-screen-keyboard.service && printf 'started\\n'; fi"]);
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
      popupDismissInProgress = false;
      bluetoothService.stopDiscovery();
    }
  }

  Keys.onEscapePressed: {
    if (overlayDismissActive)
      dismissOverlaySection();
    else
      root.closeRequested();
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
      if (root.notificationsOpen && root.notificationCenter)
        root.notificationCenter.markAllRead();
    }
  }

  Connections {
    target: root.notificationCenter
    ignoreUnknownSignals: true

    function onRevisionChanged() {
      root.syncExpandedNotificationGroups();
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
      if (!brightnessCommitTimer.running)
        root.pendingScreenBrightness = screenPercent;
    }
  }

  Services.LightingService {
    id: lightingService
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

    Component.onCompleted: exited.connect(function (exitCode) {
      root.powerProfileBusy = false;
      root.powerProfileError = exitCode === 0 ? "" : (String(powerProfileWriteStderr.text || "").trim() || "Unable to change the power profile.");
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

    Component.onCompleted: exited.connect(function (exitCode) {
      const action = String(onScreenKeyboardStdout.text || "").trim();
      root.onScreenKeyboardBusy = false;
      root.onScreenKeyboardFailed = exitCode !== 0;
      root.onScreenKeyboardMessage = exitCode === 0 ? (action === "started" ? "On-screen keyboard started." : "On-screen keyboard toggled.") : (String(onScreenKeyboardStderr.text || "").trim() || "Unable to control the on-screen keyboard.");
    })
  }

  StdioCollector {
    id: keyboardRecoveryStderr
    waitForEnd: true
  }

  Process {
    id: keyboardRecoveryProcess

    stderr: keyboardRecoveryStderr

    Component.onCompleted: exited.connect(function (exitCode) {
      root.keyboardRecoveryBusy = false;
      root.keyboardRecoveryFailed = exitCode !== 0;
      root.keyboardRecoveryMessage = exitCode === 0 ? "Keyboard recovery complete." : (String(keyboardRecoveryStderr.text || "").trim() || "Unable to recover the detachable keyboard.");

      brightnessService.refresh();
      lightingService.refresh();
    })
  }

  Timer {
    id: audioCommitTimer
    interval: 75
    repeat: false
    onTriggered: root.applyAudioVolume(root.pendingAudioVolume)
  }

  Connections {
    target: Pipewire
    ignoreUnknownSignals: true

    function onReadyChanged() {
      root.syncPendingAudioVolume();
    }
  }

  Connections {
    target: root.audioSink
    ignoreUnknownSignals: true

    function onReadyChanged() {
      root.syncPendingAudioVolume();
    }
  }

  Connections {
    target: root.audioState
    ignoreUnknownSignals: true

    function onVolumeChanged() {
      root.syncPendingAudioVolume();
    }

    function onMutedChanged() {
      root.syncPendingAudioVolume();
    }
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
    border.color: Theme.borderStrong

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
          width: Math.max(0, parent.width - (batteryChip.visible ? batteryChip.implicitWidth : 0) - onScreenKeyboardButton.implicitWidth - trayToggleButton.implicitWidth - powerToggleButton.implicitWidth - Theme.gapXs * (3 + (batteryChip.visible ? 1 : 0)))
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
              iconName: root.audioReady && root.audioState.muted ? "speaker-muted" : "speaker"
              active: root.audioReady && root.audioState.muted
              enabled: root.audioReady
              onClicked: {
                if (root.audioReady)
                  root.audioState.muted = !root.audioState.muted;
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
          onValueMoved: function (value) {
            if (!root.audioReady)
              return;
            root.pendingAudioVolume = value;
            if (root.audioState.muted)
              root.audioState.muted = false;
            audioCommitTimer.restart();
          }
          onValueCommitted: function (value) {
            if (!root.audioReady)
              return;
            root.pendingAudioVolume = value;
            audioCommitTimer.stop();
            root.applyAudioVolume(value);
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
        visible: !root.audioLoading && !root.audioReady && Pipewire.ready
        text: root.audioSink ? "Audio unavailable." : "No audio output available."
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
          value: root.pendingScreenBrightness
          enabled: brightnessService.screenAvailable
          onValueMoved: function (value) {
            root.pendingScreenBrightness = value;
            brightnessCommitTimer.restart();
          }
          onValueCommitted: function (value) {
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
          height: root.expandedSection === "wifi" ? wifiMenuPanel.implicitHeight : (root.expandedSection === "bluetooth" ? bluetoothMenuPanel.implicitHeight : quickTileRow.implicitHeight)

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

        Column {
          id: profileSection

          width: parent.width
          spacing: Theme.gapXs

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

          UiText {
            visible: root.powerProfileError !== ""
            width: parent.width
            text: root.powerProfileError
            size: "xs"
            tone: "accent"
            wrapMode: Text.WordWrap
          }
        }
      }

      Item {
        id: notificationSection

        width: parent.width
        height: root.notificationsOpen ? notificationMenuPanel.implicitHeight : notificationsFooter.implicitHeight

        ControlCenterParts.NotificationFooter {
          id: notificationsFooter

          controller: root
          visible: !root.notificationsOpen
          width: parent.width
        }
      }
    }

    UiScrim {
      anchors.fill: parent
      radius: panel.radius
      visible: root.overlayDismissActive
      z: 3

      MouseArea {
        anchors.fill: parent
        onPressed: root.dismissOverlaySection()
      }
    }
  }

  Controls.FocusPopup {
    id: powerPopup

    open: root.powerMenuOpen
    section: "power"
    parentWindow: root.popupParentWindow
    anchorItem: powerPopoverSpacer
    popupWidth: content.width
    popupHeight: powerPopover.implicitHeight
    onDismissed: function (section) {
      root.popupDismissed(section);
    }

    ControlCenterParts.PowerPopover {
      id: powerPopover

      controller: root
      width: powerPopup.popupWidth
    }
  }

  Controls.FocusPopup {
    id: outputsPopup

    open: root.outputMenuOpen
    section: "outputs"
    parentWindow: root.popupParentWindow
    anchorItem: outputsPopoverSpacer
    popupWidth: content.width
    popupHeight: outputsPopover.implicitHeight
    onDismissed: function (section) {
      root.popupDismissed(section);
    }

    ControlCenterParts.OutputsPopover {
      id: outputsPopover

      controller: root
      width: outputsPopup.popupWidth
    }
  }

  Controls.FocusPopup {
    id: wifiPopup

    open: root.expandedSection === "wifi"
    section: "wifi"
    parentWindow: root.popupParentWindow
    anchorItem: quickTileSection
    popupWidth: content.width
    popupHeight: wifiMenuPanel.implicitHeight
    onDismissed: function (section) {
      root.popupDismissed(section);
    }

    ControlCenterParts.WifiPopover {
      id: wifiMenuPanel

      controller: root
      wifiService: wifiService
      width: wifiPopup.popupWidth
    }
  }

  Controls.FocusPopup {
    id: bluetoothPopup

    open: root.expandedSection === "bluetooth"
    section: "bluetooth"
    parentWindow: root.popupParentWindow
    anchorItem: quickTileSection
    popupWidth: content.width
    popupHeight: bluetoothMenuPanel.implicitHeight
    onDismissed: function (section) {
      root.popupDismissed(section);
    }

    ControlCenterParts.BluetoothPopover {
      id: bluetoothMenuPanel

      controller: root
      bluetoothService: bluetoothService
      width: bluetoothPopup.popupWidth
    }
  }

  Controls.FocusPopup {
    id: profilePopup

    open: root.expandedSection === "profile"
    section: "profile"
    parentWindow: root.popupParentWindow
    anchorItem: profileTile
    anchorOffsetY: Math.round((profileTile.height - profilePopup.popupHeight) / 2)
    popupWidth: profilePopover.implicitWidth
    popupHeight: profilePopover.implicitHeight
    onDismissed: function (section) {
      root.popupDismissed(section);
    }

    Controls.PopoverSurface {
      id: profilePopover

      width: profilePopup.popupWidth

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
  }

  Controls.FocusPopup {
    id: lightingPopup

    open: root.expandedSection === "lighting" && lightingService.commandAvailable
    section: "lighting"
    parentWindow: root.popupParentWindow
    anchorItem: lightingTile
    anchorOffsetY: Math.round((lightingTile.height - lightingPopup.popupHeight) / 2)
    popupWidth: lightingTile.width
    popupHeight: lightingPopover.implicitHeight
    onDismissed: function (section) {
      root.popupDismissed(section);
    }

    Controls.PopoverSurface {
      id: lightingPopover

      width: lightingPopup.popupWidth

      visible: lightingService.commandAvailable

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

  Controls.FocusPopup {
    id: notificationsPopup

    open: root.notificationsOpen
    section: "notifications"
    parentWindow: root.popupParentWindow
    anchorItem: notificationSection
    popupWidth: content.width
    popupHeight: notificationMenuPanel.implicitHeight
    onDismissed: function () {
      root.popupDismissInProgress = true;
      if (root.notificationsOpen)
        root.returnFromNotifications();
      Qt.callLater(function () {
        root.popupDismissInProgress = false;
      });
    }

    ControlCenterParts.NotificationsPopover {
      id: notificationMenuPanel

      controller: root
      width: notificationsPopup.popupWidth
    }
  }
}
