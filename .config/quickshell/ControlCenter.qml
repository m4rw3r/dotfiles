pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import Quickshell.Widgets
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
  property bool bluetoothBusy: false
  property bool bluetoothEnableAfterUnblock: false
  property bool bluetoothRfkillKnown: false
  property bool bluetoothRfkillRefreshing: false
  property bool bluetoothRfkillRefreshQueued: false
  property bool bluetoothSoftBlocked: false
  property bool bluetoothHardBlocked: false
  property bool bluetoothLastErrorFromRefresh: false
  property string bluetoothLastError: ""
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
  readonly property bool powerMenuOpen: expandedSection === "power"
  readonly property bool outputMenuOpen: expandedSection === "outputs"
  readonly property bool selectorPopoverOpen: expandedSection === "profile" || (expandedSection === "lighting" && lightingService.commandAvailable)
  readonly property bool tileMenuOpen: expandedSection === "wifi" || expandedSection === "bluetooth"
  readonly property bool overlayDismissActive: selectorPopoverOpen || tileMenuOpen || powerMenuOpen || outputMenuOpen || notificationsOpen
  readonly property var audioSink: Pipewire.defaultAudioSink
  readonly property var battery: UPower.displayDevice
  property var bluetoothAdapter: null
  readonly property bool bluetoothBlocked: !!bluetoothAdapter
    && (bluetoothAdapter.state === BluetoothAdapterState.Blocked || bluetoothSoftBlocked || bluetoothHardBlocked)
  readonly property bool batteryAvailable: battery && battery.isPresent && battery.isLaptopBattery
  readonly property bool audioReady: audioService.ready
  readonly property bool audioLoading: panelOpen && !audioService.settled
  readonly property bool brightnessLoading: panelOpen && !brightnessService.settled
  readonly property bool wifiLoading: panelOpen && !wifiService.ready
  readonly property var powerMenuEntries: [
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
    bluetoothAdapter = currentBluetoothAdapter();
    refreshPanelData();
    panelRefreshTimer.restart();
  }

  onBluetoothAdapterChanged: refreshBluetoothRfkillState()
  onNotificationsOpenChanged: {
    if (notificationsOpen && notificationCenter) notificationCenter.markAllRead();
  }

  function clamp(value, minValue, maxValue) {
    return Math.max(minValue, Math.min(maxValue, value));
  }

  function currentBluetoothAdapter() {
    return Bluetooth[bluetoothAdapterKey];
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
    if (expandedSection === "bluetooth") refreshBluetoothRfkillState();
    if (expandedSection !== "bluetooth" && bluetoothAdapter) bluetoothAdapter.discovering = false;
  }

  function toggleNotificationsSection() {
    if (notificationsOpen) {
      expandedSection = notificationReturnSection;
      notificationReturnSection = "";
      return;
    }

    notificationReturnSection = expandedSection === "notifications" ? "" : expandedSection;
    expandedSection = "notifications";
    if (notificationCenter) notificationCenter.markAllRead();
  }

  function isNotificationGroupExpanded(groupKey) {
    return !!expandedNotificationGroups[groupKey];
  }

  function toggleNotificationGroup(groupKey) {
    const nextState = Object.assign({}, expandedNotificationGroups);
    nextState[groupKey] = !nextState[groupKey];
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

  function bluetoothRfkillCommand(prefix) {
    const scriptPrefix = prefix || "";
    const script = `${scriptPrefix}for d in /sys/class/rfkill/rfkill*; do [ -r "$d/type" ] || continue; type=$(cat "$d/type"); [ "$type" = "bluetooth" ] || continue; name=$(cat "$d/name" 2>/dev/null || printf ''); soft=$(cat "$d/soft" 2>/dev/null || printf '0'); hard=$(cat "$d/hard" 2>/dev/null || printf '0'); printf '%s\t%s\t%s\n' "$name" "$soft" "$hard"; done`;
    return ["sh", "-lc", script];
  }

  function parseBluetoothRfkillState(text) {
    let softBlocked = false;
    let hardBlocked = false;

    const lines = String(text || "").split("\n");
    for (let i = 0; i < lines.length; i += 1) {
      const line = lines[i].trim();
      if (line === "") continue;

      const fields = line.split("\t");
      if (fields.length < 3) continue;

      if (fields[1] === "1") softBlocked = true;
      if (fields[2] === "1") hardBlocked = true;
    }

    bluetoothSoftBlocked = softBlocked;
    bluetoothHardBlocked = hardBlocked;
    bluetoothRfkillKnown = true;
  }

  function refreshBluetoothRfkillState() {
    if (bluetoothRfkillRefreshing) {
      bluetoothRfkillRefreshQueued = true;
      return;
    }

    bluetoothRfkillRefreshing = true;
    bluetoothRfkillStateProcess.exec(bluetoothRfkillCommand(""));
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

  function bluetoothConnectedCount() {
    if (!bluetoothAdapter || !bluetoothAdapter.devices) return 0;
    let count = 0;
    for (let i = 0; i < bluetoothAdapter.devices.count; i += 1) {
      const device = bluetoothAdapter.devices.get(i);
      if (device && device.connected) count += 1;
    }
    return count;
  }

  function bluetoothAvailableCount() {
    if (!bluetoothAdapter || !bluetoothAdapter.devices) return 0;
    let count = 0;
    for (let i = 0; i < bluetoothAdapter.devices.count; i += 1) {
      const device = bluetoothAdapter.devices.get(i);
      if (device && !device.connected) count += 1;
    }
    return count;
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
    const count = bluetoothConnectedCount();
    if (count > 0) return count === 1 ? "1 Device" : `${count} Devices`;
    return "Bluetooth";
  }

  function bluetoothTileSubtitle() {
    if (!bluetoothAdapter) return "Unavailable";
    if (bluetoothBusy && bluetoothEnableAfterUnblock) return "Unblocking...";
    if (bluetoothHardBlocked) return "Hardware Blocked";
    if (bluetoothBlocked) return "Blocked";
    if (!bluetoothAdapter.enabled) return "Off";
    return bluetoothAdapter.discovering ? "Scanning" : "Ready";
  }

  function bluetoothBlockedMessage() {
    if (!bluetoothBlocked) return "";
    if (bluetoothBusy && bluetoothEnableAfterUnblock) return "Unblocking Bluetooth...";
    if (bluetoothHardBlocked) return "Bluetooth is blocked by hardware or firmware airplane mode.";
    if (bluetoothSoftBlocked) return "Bluetooth is blocked by rfkill. Turn On will unblock it.";
    if (!bluetoothRfkillKnown) return "Bluetooth is blocked. Turn On will try to unblock it.";
    return "Bluetooth is blocked.";
  }

  function bluetoothPrimaryActionText() {
    if (bluetoothBusy && bluetoothEnableAfterUnblock) return "Unblocking...";
    if (bluetoothHardBlocked) return "Blocked";
    return bluetoothAdapter && bluetoothAdapter.enabled ? "Turn Off" : "Turn On";
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
    refreshBluetoothRfkillState();
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
    if (!bluetoothAdapter || bluetoothBusy) return;

    bluetoothLastErrorFromRefresh = false;
    bluetoothLastError = "";

    if (bluetoothHardBlocked) {
      bluetoothLastErrorFromRefresh = false;
      bluetoothLastError = "Bluetooth is hard blocked by hardware or firmware airplane mode.";
      refreshBluetoothRfkillState();
      return;
    }

    if (bluetoothBlocked) {
      bluetoothBusy = true;
      bluetoothEnableAfterUnblock = true;
      bluetoothUnblockProcess.exec(bluetoothRfkillCommand("rfkill unblock bluetooth && "));
      return;
    }

    bluetoothAdapter.enabled = !bluetoothAdapter.enabled;
    if (!bluetoothAdapter.enabled) bluetoothAdapter.discovering = false;
    refreshBluetoothRfkillState();
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
      if (bluetoothAdapter) bluetoothAdapter.discovering = false;
    }
  }

  Connections {
    target: Bluetooth
    ignoreUnknownSignals: true

    function onDefaultAdapterChanged() {
      root.bluetoothAdapter = root.currentBluetoothAdapter();
      root.refreshBluetoothRfkillState();
    }
  }

  Connections {
    target: root.bluetoothAdapter
    ignoreUnknownSignals: true

    function onStateChanged() {
      root.refreshBluetoothRfkillState();
    }

    function onEnabledChanged() {
      root.refreshBluetoothRfkillState();
    }
  }

  Keys.onEscapePressed: root.closeRequested()

  Timer {
    id: powerConfirmTimer
    interval: 2200
    repeat: false
    onTriggered: root.pendingPowerAction = ""
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

  BrightnessController {
    id: brightnessService

    onScreenPercentChanged: {
      if (!brightnessCommitTimer.running) root.pendingScreenBrightness = screenPercent;
    }
  }

  LightingController {
    id: lightingService
  }

  Item {
    id: audioService

    property real volume: 0
    property bool muted: false
    property bool ready: false
    property bool settled: false
    property string lastError: ""

    function refresh() {
      readProcess.exec(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]);
    }

    function setVolume(nextVolume) {
      const clamped = Math.max(0, Math.min(1, Number(nextVolume)));
      volume = clamped;
      if (clamped > 0 && muted) muted = false;
      lastError = "";
      writeProcess.exec(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", clamped.toFixed(3)]);
    }

    function setMuted(nextMuted) {
      muted = nextMuted;
      lastError = "";
      muteProcess.exec(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", nextMuted ? "1" : "0"]);
    }

    function toggleMuted() {
      setMuted(!muted);
    }

    function parseState(text) {
      const match = String(text || "").match(/Volume:\s+([0-9.]+)(?:\s+\[(MUTED)\])?/i);
      settled = true;

      if (!match) {
        ready = false;
        lastError = "Unable to parse current volume.";
        return;
      }

      volume = Math.max(0, Math.min(1, Number(match[1]) || 0));
      muted = match[2] === "MUTED";
      ready = true;
    }

    onVolumeChanged: {
      if (!audioCommitTimer.running) root.pendingAudioVolume = volume;
    }

    StdioCollector {
      id: audioReadStdout
      waitForEnd: true
    }

    StdioCollector {
      id: audioReadStderr
      waitForEnd: true
    }

    Process {
      id: readProcess

      stdout: audioReadStdout
      stderr: audioReadStderr

      Component.onCompleted: exited.connect(function(exitCode) {

        audioService.settled = true;
        audioService.lastError = exitCode === 0 ? "" : String(audioReadStderr.text || "").trim();
        if (exitCode === 0) audioService.parseState(audioReadStdout.text);
        else audioService.ready = false;
      })
    }

    StdioCollector {
      id: audioWriteStderr
      waitForEnd: true
    }

    StdioCollector {
      id: audioMuteStderr
      waitForEnd: true
    }

    Process {
      id: writeProcess

      stderr: audioWriteStderr

      Component.onCompleted: exited.connect(function(exitCode) {

        audioService.lastError = exitCode === 0 ? "" : String(audioWriteStderr.text || "").trim();
        audioRefreshTimer.restart();
      })
    }

    Process {
      id: muteProcess

      stderr: audioMuteStderr

      Component.onCompleted: exited.connect(function(exitCode) {

        audioService.lastError = exitCode === 0 ? "" : String(audioMuteStderr.text || "").trim();
        audioRefreshTimer.restart();
      })
    }

    Timer {
      id: audioRefreshTimer
      interval: 150
      repeat: false
      onTriggered: audioService.refresh()
    }
  }

  WifiController {
    id: wifiService

    onConnectedSsidChanged: {
      root.wifiPasswordTarget = "";
      root.wifiPassword = "";
    }
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
    id: bluetoothRfkillStateStdout
    waitForEnd: true
  }

  StdioCollector {
    id: bluetoothRfkillStateStderr
    waitForEnd: true
  }

  Process {
    id: bluetoothRfkillStateProcess

    stdout: bluetoothRfkillStateStdout
    stderr: bluetoothRfkillStateStderr

    Component.onCompleted: exited.connect(function(exitCode) {

      root.bluetoothRfkillRefreshing = false;

      const stderrText = String(bluetoothRfkillStateStderr.text || "").trim();
      const stdoutText = bluetoothRfkillStateStdout.text;

      if (exitCode === 0) {
        root.parseBluetoothRfkillState(stdoutText);
        if (root.bluetoothLastErrorFromRefresh) {
          root.bluetoothLastError = "";
          root.bluetoothLastErrorFromRefresh = false;
        }
      } else {
        root.bluetoothRfkillKnown = false;
        root.bluetoothSoftBlocked = false;
        root.bluetoothHardBlocked = false;
        if (root.bluetoothLastError === "") {
          root.bluetoothLastErrorFromRefresh = true;
          root.bluetoothLastError = stderrText !== "" ? stderrText : "Unable to inspect Bluetooth block state.";
        }
      }

      if (root.bluetoothRfkillRefreshQueued) {
        root.bluetoothRfkillRefreshQueued = false;
        root.refreshBluetoothRfkillState();
      }
    })
  }

  StdioCollector {
    id: bluetoothUnblockStdout
    waitForEnd: true
  }

  StdioCollector {
    id: bluetoothUnblockStderr
    waitForEnd: true
  }

  Process {
    id: bluetoothUnblockProcess

    stdout: bluetoothUnblockStdout
    stderr: bluetoothUnblockStderr

    Component.onCompleted: exited.connect(function(exitCode) {

      root.bluetoothBusy = false;
      root.bluetoothEnableAfterUnblock = false;

      const stderrText = String(bluetoothUnblockStderr.text || "").trim();
      const stdoutText = bluetoothUnblockStdout.text;

      if (exitCode === 0) {
        root.parseBluetoothRfkillState(stdoutText);

        if (root.bluetoothHardBlocked) {
          root.bluetoothLastErrorFromRefresh = false;
          root.bluetoothLastError = "Bluetooth is hard blocked by hardware or firmware airplane mode.";
          return;
        }

        if (root.bluetoothSoftBlocked) {
          root.bluetoothLastErrorFromRefresh = false;
          root.bluetoothLastError = "Bluetooth is still soft blocked after the unblock attempt.";
          return;
        }

        root.bluetoothLastErrorFromRefresh = false;
        root.bluetoothLastError = "";
        if (root.bluetoothAdapter) root.bluetoothAdapter.enabled = true;
        root.refreshBluetoothRfkillState();
        return;
      }

      root.bluetoothLastErrorFromRefresh = false;
      root.bluetoothLastError = stderrText !== "" ? stderrText : "Unable to unblock Bluetooth.";
      root.refreshBluetoothRfkillState();
    })
  }

  component BrightnessController: Item {
    id: brightnessController

    property bool ready: false
    property bool settled: false
    property bool screenLoaded: false
    property string screenDevice: ""
    property string keyboardDevice: ""
    property int screenPercent: 0
    property int keyboardPercent: 0
    property int keyboardValue: 0
    property int keyboardMax: 0
    property string lastError: ""
    readonly property bool screenAvailable: screenDevice !== ""
    readonly property bool keyboardAvailable: keyboardDevice !== "" && keyboardMax > 0

    function refresh() {
      if (!ready) {
        detectProcess.exec(["brightnessctl", "--list"]);
        return;
      }

      refreshScreen();
      refreshKeyboard();
    }

    function refreshScreen() {
      if (!screenAvailable) return;
      screenReadProcess.exec(["brightnessctl", "-m", "-d", screenDevice]);
    }

    function refreshKeyboard() {
      if (!keyboardAvailable) return;
      keyboardReadProcess.exec(["brightnessctl", "-m", "-d", keyboardDevice]);
    }

    function applyScreenPercent(percent) {
      if (!screenAvailable) return;
      screenWriteProcess.exec(["brightnessctl", "-d", screenDevice, "set", `${Math.round(percent)}%`]);
    }

    function applyKeyboardValue(value) {
      if (!keyboardAvailable) return;
      keyboardWriteProcess.exec(["brightnessctl", "-d", keyboardDevice, "set", `${Math.round(value)}`]);
    }

    function parseDeviceList(text) {
      const lines = String(text || "").split("\n");
      let nextScreen = "";
      let nextKeyboard = "";

      for (let i = 0; i < lines.length; i += 1) {
        const line = lines[i];
        const match = line.match(/^Device '([^']+)' of class '([^']+)'/);
        if (!match) continue;

        const deviceName = match[1];
        const deviceClass = match[2];

        if (deviceClass === "backlight" && nextScreen === "") nextScreen = deviceName;
        if (deviceClass === "leds" && deviceName.indexOf("kbd_backlight") >= 0) {
          if (nextKeyboard === "" || deviceName.indexOf("::kbd_backlight") >= 0) nextKeyboard = deviceName;
        }
      }

      screenDevice = nextScreen;
      keyboardDevice = nextKeyboard;
      screenLoaded = false;
      settled = nextScreen === "";
      ready = true;
      refreshScreen();
      refreshKeyboard();
    }

    function parseBrightness(text, isKeyboard) {
      const line = String(text || "").trim();
      if (line === "") return;

      const parts = line.split(",");
      if (parts.length < 5) return;

      const percent = parseInt(String(parts[3]).replace("%", ""));
      if (!Number.isFinite(percent)) return;

      if (isKeyboard) {
        keyboardPercent = percent;
        keyboardValue = parseInt(parts[2]) || 0;
        keyboardMax = parseInt(parts[4]) || 0;
      } else {
        screenLoaded = true;
        screenPercent = percent;
      }
    }

    StdioCollector {
      id: detectStdout
      waitForEnd: true
    }

    StdioCollector {
      id: detectStderr
      waitForEnd: true
    }

    Process {
      id: detectProcess

      stdout: detectStdout
      stderr: detectStderr

      Component.onCompleted: exited.connect(function(exitCode) {

        brightnessController.lastError = exitCode === 0 ? "" : String(detectStderr.text || "").trim();
        if (exitCode === 0) brightnessController.parseDeviceList(detectStdout.text);
        else brightnessController.settled = true;
      })
    }

    StdioCollector {
      id: screenStdout
      waitForEnd: true
    }

    Process {
      id: screenReadProcess
      stdout: screenStdout
      Component.onCompleted: exited.connect(function(exitCode) {

        brightnessController.settled = true;
        if (exitCode === 0) brightnessController.parseBrightness(screenStdout.text, false);
      })
    }

    StdioCollector {
      id: keyboardStdout
      waitForEnd: true
    }

    Process {
      id: keyboardReadProcess
      stdout: keyboardStdout
      Component.onCompleted: exited.connect(function(exitCode) {

        if (exitCode === 0) brightnessController.parseBrightness(keyboardStdout.text, true);
      })
    }

    StdioCollector {
      id: screenWriteStderr
      waitForEnd: true
    }

    Process {
      id: screenWriteProcess
      stderr: screenWriteStderr
      Component.onCompleted: exited.connect(function(exitCode) {

        brightnessController.lastError = exitCode === 0 ? "" : String(screenWriteStderr.text || "").trim();
        brightnessController.refreshScreen();
      })
    }

    StdioCollector {
      id: keyboardWriteStderr
      waitForEnd: true
    }

    Process {
      id: keyboardWriteProcess
      stderr: keyboardWriteStderr
      Component.onCompleted: exited.connect(function(exitCode) {

        brightnessController.lastError = exitCode === 0 ? "" : String(keyboardWriteStderr.text || "").trim();
        brightnessController.refreshKeyboard();
      })
    }
  }

  component LightingController: Item {
    id: lightingController

    property bool commandAvailable: false
    property bool available: false
    property bool settled: false
    property string level: "off"
    property string lastError: ""

    function refresh() {
      stateReadProcess.exec([
        "zsh",
        "-lc",
        "command -v z13ctl >/dev/null 2>&1 || exit 127; state_file=${XDG_STATE_HOME:-$HOME/.local/state}/z13ctl/state.json; [ -r \"$state_file\" ] || exit 66; command cat \"$state_file\""
      ]);
    }

    function applyLevel(nextLevel) {
      if (!available) return;
      lastError = "";
      lightingWriteProcess.exec(["zsh", "-lc", `z13ctl brightness ${nextLevel}`]);
    }

    function parseState(text) {
      let parsed;

      try {
        parsed = JSON.parse(String(text || "{}"));
      } catch (error) {
        commandAvailable = true;
        available = false;
        settled = true;
        level = "off";
        lastError = "Unable to parse lighting state.";
        return;
      }

      const lighting = parsed && parsed.lighting ? parsed.lighting : null;
      const keyboard = parsed && parsed.devices && parsed.devices.keyboard ? parsed.devices.keyboard : null;
      if (!lighting && !keyboard) {
        commandAvailable = true;
        available = false;
        settled = true;
        level = "off";
        lastError = "Lighting state unavailable.";
        return;
      }

      const enabled = lighting && lighting.enabled !== undefined
        ? Boolean(lighting.enabled)
        : (keyboard && keyboard.enabled !== undefined ? Boolean(keyboard.enabled) : false);
      const brightness = lighting && lighting.brightness !== undefined
        ? Number(lighting.brightness)
        : (keyboard && keyboard.brightness !== undefined ? Number(keyboard.brightness) : 0);

      commandAvailable = true;
      available = true;
      settled = true;
      lastError = "";

      if (!enabled || !Number.isFinite(brightness) || brightness <= 0) {
        level = "off";
        return;
      }

      if (brightness >= 3) {
        level = "high";
        return;
      }

      if (brightness >= 2) {
        level = "medium";
        return;
      }

      level = "low";
    }

    StdioCollector {
      id: lightingStateStdout
      waitForEnd: true
    }

    StdioCollector {
      id: lightingStateStderr
      waitForEnd: true
    }

    Process {
      id: stateReadProcess

      stdout: lightingStateStdout
      stderr: lightingStateStderr

      Component.onCompleted: exited.connect(function(exitCode) {

        lightingController.settled = true;
        if (exitCode === 0) {
          lightingController.parseState(lightingStateStdout.text);
          return;
        }

        lightingController.commandAvailable = exitCode !== 127;
        lightingController.available = false;
        lightingController.level = "off";
        lightingController.lastError = exitCode === 127
          ? ""
          : (exitCode === 66 ? "Lighting state unavailable." : String(lightingStateStderr.text || "").trim());
      })
    }

    StdioCollector {
      id: lightingWriteStderr
      waitForEnd: true
    }

    Process {
      id: lightingWriteProcess

      stderr: lightingWriteStderr

      Component.onCompleted: exited.connect(function(exitCode) {

        lightingController.lastError = exitCode === 0 ? "" : String(lightingWriteStderr.text || "").trim();
        lightingRefreshTimer.restart();
      })
    }

    Timer {
      id: lightingRefreshTimer
      interval: 150
      repeat: false
      onTriggered: lightingController.refresh()
    }
  }

  component WifiController: Item {
    id: wifiController

    property bool ready: false
    property bool enabled: false
    property bool hardwareEnabled: true
    property bool busy: false
    property string connectedSsid: ""
    property int connectedSignal: 0
    property var savedNetworks: ({})
    property var networks: []
    property string lastError: ""
    property string pendingSsid: ""

    function splitEscaped(line) {
      const fields = [];
      let current = "";
      let escaping = false;

      for (let i = 0; i < line.length; i += 1) {
        const character = line[i];

        if (escaping) {
          current += character;
          escaping = false;
          continue;
        }

        if (character === "\\") {
          escaping = true;
          continue;
        }

        if (character === ":") {
          fields.push(current);
          current = "";
          continue;
        }

        current += character;
      }

      fields.push(current);
      return fields;
    }

    function refresh() {
      busy = true;
      lastError = "";
      refreshProcess.exec([
        "sh",
        "-lc",
        "saved_file=$(mktemp) || exit 1; connections_file=$(mktemp) || exit 1; wifi_file=$(mktemp) || exit 1; trap 'rm -f \"$saved_file\" \"$connections_file\" \"$wifi_file\"' EXIT; status_failed=0; saved_failed=0; wifi_failed=0; status_output=$(nmcli -t -f WIFI,WIFI-HW general status) || status_failed=1; if ! nmcli -t --escape yes -f UUID,TYPE connection show >\"$connections_file\"; then saved_failed=1; else while IFS=: read -r uuid type; do [ \"$type\" = \"802-11-wireless\" ] || continue; if ! nmcli -t --escape yes -g 802-11-wireless.ssid connection show uuid \"$uuid\" >>\"$saved_file\"; then saved_failed=1; break; fi; done <\"$connections_file\"; fi; if ! nmcli -t --escape yes -f IN-USE,BSSID,SSID,SIGNAL,SECURITY device wifi list --rescan no >\"$wifi_file\"; then wifi_failed=1; fi; printf '%s\n@@SAVED@@\n' \"$status_output\"; if [ \"$saved_failed\" -eq 0 ]; then cat \"$saved_file\"; fi; printf '\n@@WIFI@@\n'; if [ \"$wifi_failed\" -eq 0 ]; then cat \"$wifi_file\"; fi; printf '\n@@ERRORS@@\n'; if [ \"$status_failed\" -ne 0 ]; then printf 'status\n'; fi; if [ \"$saved_failed\" -ne 0 ]; then printf 'saved\n'; fi; if [ \"$wifi_failed\" -ne 0 ]; then printf 'wifi\n'; fi"
      ]);
    }

    function scan() {
      busy = true;
      lastError = "";
      scanProcess.exec(["nmcli", "device", "wifi", "rescan"]);
    }

    function setEnabledState(nextState) {
      busy = true;
      lastError = "";
      toggleProcess.exec(["nmcli", "radio", "wifi", nextState ? "on" : "off"]);
    }

    function connectNetwork(ssid, password) {
      if (ssid === "") return;

      const command = ["nmcli", "device", "wifi", "connect", ssid];
      if (password !== "") command.push("password", password);

      busy = true;
      lastError = "";
      pendingSsid = ssid;
      connectProcess.exec(command);
    }

    function parseRefresh(text) {
      const blocks = String(text || "").split("\n@@SAVED@@\n");
      const statusBlock = blocks.length > 0 ? blocks[0] : "";
      const remainder = blocks.length > 1 ? blocks[1] : "";
      const savedBlocks = remainder.split("\n@@WIFI@@\n");
      const savedBlock = savedBlocks.length > 0 ? savedBlocks[0] : "";
      const wifiAndErrors = savedBlocks.length > 1 ? savedBlocks[1] : "";
      const wifiBlocks = wifiAndErrors.split("\n@@ERRORS@@\n");
      const wifiBlock = wifiBlocks.length > 0 ? wifiBlocks[0] : "";
      const errorBlock = wifiBlocks.length > 1 ? wifiBlocks[1] : "";
      const refreshErrors = parseRefreshErrors(errorBlock);

      if (!refreshErrors.statusFailed) parseStatus(statusBlock);
      if (!refreshErrors.savedFailed) parseSaved(savedBlock);
      if (!refreshErrors.wifiFailed) parseWifiList(wifiBlock);
    }

    function parseRefreshErrors(text) {
      const result = {
        statusFailed: false,
        savedFailed: false,
        wifiFailed: false
      };

      const lines = String(text || "").split("\n");
      for (let i = 0; i < lines.length; i += 1) {
        const line = lines[i].trim();
        if (line === "status") result.statusFailed = true;
        else if (line === "saved") result.savedFailed = true;
        else if (line === "wifi") result.wifiFailed = true;
      }

      return result;
    }

    function hasRefreshPayload(text) {
      const payload = String(text || "");
      return payload.indexOf("\n@@SAVED@@\n") >= 0
        && payload.indexOf("\n@@WIFI@@\n") >= 0
        && payload.indexOf("\n@@ERRORS@@\n") >= 0;
    }

    function parseStatus(text) {
      const line = String(text || "").trim();
      if (line === "") return;

      const parts = line.split(":");
      enabled = parts[0] === "enabled";
      hardwareEnabled = parts.length < 2 ? true : parts[1] === "enabled";
    }

    function parseSaved(text) {
      const lines = String(text || "").split("\n");
      const known = {};

      for (let i = 0; i < lines.length; i += 1) {
        const line = lines[i];
        if (line === "") continue;

        const fields = splitEscaped(line);
        const ssid = fields.length > 0 ? fields[0] : "";
        if (ssid === "") continue;
        known[ssid] = true;
      }

      savedNetworks = known;
    }

    function parseWifiList(text) {
      const lines = String(text || "").split("\n");
      const deduped = {};
      let activeSsid = "";
      let activeSignal = 0;

      for (let i = 0; i < lines.length; i += 1) {
        const line = lines[i];
        if (line === "") continue;

        const parts = splitEscaped(line);
        if (parts.length < 5) continue;

        const active = parts[0] === "*";
        const bssid = parts[1];
        const ssid = parts[2];
        const signal = parseInt(parts[3]) || 0;
        const security = parts[4];

        if (ssid === "") continue;

        const network = {
          active,
          bssid,
          ssid,
          signal,
          security,
          secure: security !== "",
          known: savedNetworks[ssid] === true
        };

        if (active) {
          activeSsid = ssid;
          activeSignal = signal;
        }

        const networkKey = bssid !== "" ? bssid : `${ssid}\u0000${security}`;
        const existing = deduped[networkKey];
        if (!existing || existing.signal < network.signal || (network.active && !existing.active)) {
          deduped[networkKey] = network;
        }
      }

      const nextNetworks = Object.values(deduped);
      nextNetworks.sort((left, right) => {
        if (left.active !== right.active) return left.active ? -1 : 1;
        if (left.known !== right.known) return left.known ? -1 : 1;
        if (left.signal !== right.signal) return right.signal - left.signal;
        const byName = left.ssid.localeCompare(right.ssid);
        if (byName !== 0) return byName;
        return String(left.bssid || "").localeCompare(String(right.bssid || ""));
      });

      connectedSsid = activeSsid;
      connectedSignal = activeSignal;
      networks = nextNetworks;
    }

    StdioCollector {
      id: wifiRefreshStdout
      waitForEnd: true
    }

    StdioCollector {
      id: wifiRefreshStderr
      waitForEnd: true
    }

    Process {
      id: refreshProcess

      stdout: wifiRefreshStdout
      stderr: wifiRefreshStderr

      Component.onCompleted: exited.connect(function(exitCode) {

        wifiController.busy = false;
        wifiController.ready = true;
        const stderrText = String(wifiRefreshStderr.text || "").trim();
        const stdoutText = wifiRefreshStdout.text;

        if (exitCode === 0 && wifiController.hasRefreshPayload(stdoutText)) {
          wifiController.parseRefresh(stdoutText);
          wifiController.lastError = stderrText;
          return;
        }

        wifiController.lastError = stderrText !== "" ? stderrText : "Unable to refresh Wi-Fi state.";
      })
    }

    StdioCollector {
      id: wifiToggleStderr
      waitForEnd: true
    }

    StdioCollector {
      id: wifiScanStderr
      waitForEnd: true
    }

    StdioCollector {
      id: wifiConnectStderr
      waitForEnd: true
    }

    Process {
      id: toggleProcess
      stderr: wifiToggleStderr
      Component.onCompleted: exited.connect(function(exitCode) {

        wifiController.lastError = exitCode === 0 ? "" : String(wifiToggleStderr.text || "").trim();
        wifiController.refresh();
      })
    }

    Process {
      id: scanProcess
      stderr: wifiScanStderr
      Component.onCompleted: exited.connect(function(exitCode) {

        wifiController.lastError = exitCode === 0 ? "" : String(wifiScanStderr.text || "").trim();
        wifiRescanDelay.restart();
      })
    }

    Process {
      id: connectProcess
      stderr: wifiConnectStderr
      Component.onCompleted: exited.connect(function(exitCode) {

        wifiController.lastError = exitCode === 0 ? "" : String(wifiConnectStderr.text || "").trim();
        if (exitCode !== 0) wifiController.busy = false;
        wifiController.pendingSsid = "";
        wifiRescanDelay.restart();
      })
    }

    Timer {
      id: wifiRescanDelay
      interval: 700
      repeat: false
      onTriggered: wifiController.refresh()
    }
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

  component NotificationInboxCard: UiSurface {
    id: card

    required property var entry
    readonly property bool unread: !!(entry && entry.unread)
    readonly property bool critical: !!(entry && entry.urgency === NotificationUrgency.Critical)
    readonly property string primaryActionLabel: root.notificationCenter ? root.notificationCenter.primaryActionLabel(entry) : ""
    readonly property string appLabel: root.notificationCenter ? root.notificationCenter.appLabel(entry) : "Notification"
    readonly property string summaryLabel: root.notificationCenter ? root.notificationCenter.summaryLabel(entry) : ""
    readonly property string bodyLabel: root.notificationCenter ? root.notificationCenter.bodyLabel(entry) : ""

    width: parent ? parent.width : implicitWidth
    implicitHeight: cardContent.implicitHeight + Theme.insetSm * 2
    tone: critical ? "chip" : (unread ? "field" : "fieldAlt")
    outlined: false
    radius: Theme.radiusLg
    border.width: Theme.stroke
    border.color: critical
      ? Qt.rgba(1, 1, 1, 0.16)
      : (unread ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08))

    Column {
      id: cardContent

      width: parent.width - Theme.insetLg
      anchors.left: parent.left
      anchors.leftMargin: Theme.insetSm
      anchors.top: parent.top
      anchors.topMargin: Theme.insetSm
      spacing: Theme.gapXs

      Row {
        width: parent.width
        spacing: Theme.gapSm

        Item {
          width: Theme.controlSm
          height: Theme.controlSm

          UiSurface {
            anchors.fill: parent
            tone: card.critical ? "accent" : "field"
            radius: width / 2
            outlined: false
          }

          UiIcon {
            visible: !appIcon.visible
            anchors.centerIn: parent
            width: Theme.iconGlyphSm
            height: Theme.iconGlyphSm
            name: card.critical ? "bell-ring" : "bell"
            strokeColor: card.critical ? Theme.textOnAccent : Theme.text
          }

          IconImage {
            id: appIcon

            visible: source !== ""
            anchors.centerIn: parent
            implicitSize: Theme.iconGlyphSm
            asynchronous: true
            mipmap: true
            source: card.entry && card.entry.appIcon !== "" ? String(card.entry.appIcon) : ""
          }
        }

        Column {
          width: Math.max(0, parent.width - Theme.controlSm - metadataSlot.width - closeButton.implicitWidth - Theme.gapSm * 3)
          spacing: Theme.nudge

          UiText {
            width: parent.width
            text: card.appLabel
            size: "xs"
            tone: "muted"
            font.weight: Font.DemiBold
            elide: Text.ElideRight
          }

          UiText {
            width: parent.width
            text: card.summaryLabel
            size: "sm"
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            textFormat: Text.PlainText
          }
        }

        Item {
          id: metadataSlot

          width: ageLabel.implicitWidth + (unreadIndicator.visible ? unreadIndicator.width + Theme.gapXs : 0)
          height: Math.max(ageLabel.implicitHeight, unreadIndicator.visible ? unreadIndicator.height : 0)

          Rectangle {
            id: unreadIndicator

            visible: card.unread
            width: 8
            height: 8
            radius: 4
            color: card.critical ? Theme.accentStrong : Theme.toggleOn
            anchors.left: parent.left
            anchors.top: parent.top
          }

          UiText {
            id: ageLabel

            anchors.right: parent.right
            anchors.top: parent.top
            text: root.notificationCenter ? root.notificationCenter.ageLabel(card.entry) : ""
            size: "xs"
            tone: "subtle"
          }
        }

        Controls.IconButton {
          id: closeButton

          variant: "minimal"
          iconName: "x"
          onClicked: {
            if (root.notificationCenter) root.notificationCenter.forgetEntry(card.entry);
          }
        }
      }

      UiText {
        visible: text !== ""
        width: parent.width
        text: card.bodyLabel
        size: "xs"
        tone: "subtle"
        wrapMode: Text.WordWrap
        maximumLineCount: 3
        elide: Text.ElideRight
        textFormat: Text.PlainText
      }

      Row {
        visible: actionButton.visible
        spacing: Theme.gapXs

        Controls.Button {
          id: actionButton

          visible: card.primaryActionLabel !== ""
          compact: true
          text: card.primaryActionLabel
          onClicked: {
            if (root.notificationCenter) root.notificationCenter.invokePrimaryAction(card.entry);
          }
        }

      }
    }
  }

  component NotificationGroupSection: Column {
    id: groupSection

    required property var group
    readonly property bool expandable: !!group && group.entryCount > 1
    readonly property bool expanded: expandable && root.isNotificationGroupExpanded(group.key)
    readonly property var latestEntry: group ? group.latestEntry : null

    width: parent ? parent.width : implicitWidth
    spacing: Theme.gapXs

    UiSurface {
      width: parent.width
      implicitHeight: groupHeaderContent.implicitHeight + Theme.insetSm * 2
      tone: groupSection.group && groupSection.group.criticalUnreadCount > 0
        ? "chip"
        : (groupSection.group && groupSection.group.unreadCount > 0 ? "field" : "fieldAlt")
      outlined: false
      radius: Theme.radiusLg
      border.width: Theme.stroke
      border.color: groupSection.group && groupSection.group.unreadCount > 0
        ? Qt.rgba(1, 1, 1, 0.12)
        : Qt.rgba(1, 1, 1, 0.08)

      Column {
        id: groupHeaderContent

        width: parent.width - Theme.insetLg
        anchors.left: parent.left
        anchors.leftMargin: Theme.insetSm
        anchors.top: parent.top
        anchors.topMargin: Theme.insetSm
        spacing: Theme.nudge

        Row {
          width: parent.width
          spacing: Theme.gapXs

          UiText {
            width: Math.max(0, parent.width - groupMeta.implicitWidth - groupChevron.width - Theme.gapSm * 2)
            text: groupSection.group ? groupSection.group.appName : "Notifications"
            size: "xs"
            tone: "muted"
            font.weight: Font.DemiBold
            elide: Text.ElideRight
          }

          UiText {
            id: groupMeta

            text: {
              if (!groupSection.group) return "";
              if (groupSection.group.entryCount === 1) return "1 message";
              return `${groupSection.group.entryCount} messages`;
            }
            size: "xs"
            tone: groupSection.group && groupSection.group.criticalUnreadCount > 0 ? "accent" : "subtle"
          }

          UiIcon {
            id: groupChevron

            visible: groupSection.expandable
            width: Theme.iconGlyphSm
            height: Theme.iconGlyphSm
            name: groupSection.expanded ? "chevron-down" : "chevron-right"
            strokeColor: Theme.textSubtle
          }
        }

        UiText {
          width: parent.width
          text: root.notificationCenter ? root.notificationCenter.summaryLabel(groupSection.latestEntry) : ""
          size: "sm"
          font.weight: Font.DemiBold
          wrapMode: Text.WordWrap
          maximumLineCount: groupSection.expanded ? 2 : 1
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }
      }

      MouseArea {
        anchors.fill: parent
        enabled: groupSection.expandable
        onClicked: root.toggleNotificationGroup(groupSection.group.key)
      }
    }

    Item {
      width: parent.width
      height: groupSection.expanded ? groupCards.implicitHeight : 0
      clip: true

      Behavior on height {
        NumberAnimation {
          duration: Theme.motionBase
          easing.type: Easing.OutCubic
        }
      }

      Column {
        id: groupCards

        width: parent.width
        spacing: Theme.gapXs

        Repeater {
          model: groupSection.expandable && groupSection.group ? groupSection.group.entries : []

          delegate: NotificationInboxCard {
            required property var modelData
            entry: modelData
          }
        }
      }
    }
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
            - onScreenKeyboardButton.implicitWidth - keyboardRecoveryButton.implicitWidth - trayToggleButton.implicitWidth - lockButton.implicitWidth - powerToggleButton.implicitWidth
            - Theme.gapXs * (5 + (batteryChip.visible ? 1 : 0))
          )
          height: parent.height
        }

        Controls.IconButton {
          id: onScreenKeyboardButton
          anchors.verticalCenter: parent.verticalCenter
          iconSize: Theme.iconGlyphSm
          circular: true
          iconName: "keyboard"
          active: root.onScreenKeyboardBusy
          onClicked: root.toggleOnScreenKeyboard()
        }

        Controls.IconButton {
          id: keyboardRecoveryButton
          anchors.verticalCenter: parent.verticalCenter
          iconSize: Theme.iconGlyphSm
          circular: true
          iconName: "rotate-cw"
          active: root.keyboardRecoveryBusy
          onClicked: root.recoverKeyboard()
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
          id: lockButton
          anchors.verticalCenter: parent.verticalCenter
          iconSize: Theme.iconGlyphSm
          circular: true
          iconName: "lock"
          enabled: !root.sessionActionBusy
          onClicked: root.runSessionAction("lock")
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
              active: !!(root.bluetoothAdapter && root.bluetoothAdapter.enabled)
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

            Row {
              width: parent.width

              UiText {
                width: Math.max(0, parent.width - unreadBadge.width - (unreadBadge.visible ? Theme.gapXs : 0))
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
                width: visible ? Math.max(Theme.controlSm, unreadBadgeLabel.implicitWidth + Theme.gapSm) : 0
                height: visible ? Theme.controlSm - Theme.gapXs : 0
                radius: height / 2
                color: root.notificationsCriticalUnread ? Theme.accent : Theme.toggleOn
                anchors.verticalCenter: parent.verticalCenter

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

      Patterns.HeroSheetPopover {
        id: notificationMenuPanel

        visible: root.notificationsOpen
        width: content.width
        x: content.x
        y: content.y + notificationSection.y
        z: 1
        iconName: root.notificationsCriticalUnread
          ? "bell-ring"
          : "bell"
        title: "Notifications"
        subtitle: root.unreadNotificationCount > 0 && root.notificationCenter
          ? root.notificationCenter.unreadCountLabel()
          : "You're all caught up."

        Column {
          width: parent.width
          spacing: Theme.gapSm

          Flickable {
            id: notificationViewport

            width: parent.width
            height: Math.min(notificationContentColumn.implicitHeight, root.notificationViewportMaxHeight)
            clip: true
            contentWidth: width
            contentHeight: notificationContentColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
              policy: ScrollBar.AsNeeded
            }

            Column {
              id: notificationContentColumn

              width: notificationViewport.width
              spacing: Theme.gapSm

              Item {
                width: parent.width
                height: emptyNotificationsState.visible ? emptyNotificationsState.implicitHeight : 0
                visible: root.notificationCount === 0

                Column {
                  id: emptyNotificationsState

                  width: parent.width
                  spacing: Theme.gapXs

                  UiText {
                    width: parent.width
                    text: "No notifications"
                    size: "sm"
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                  }

                  UiText {
                    width: parent.width
                    text: "New messages will show up here."
                    size: "xs"
                    tone: "subtle"
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                  }
                }
              }

              Repeater {
                model: root.notificationCenter ? root.notificationCenter.groupedEntries : []

                delegate: Item {
                  required property var modelData

                  width: notificationContentColumn.width
                  height: modelData && modelData.entryCount === 1
                    ? singleNotificationCard.implicitHeight
                    : groupedNotificationSection.implicitHeight

                  NotificationInboxCard {
                    id: singleNotificationCard

                    visible: !!parent.modelData && parent.modelData.entryCount === 1
                    width: parent.width
                    entry: parent.modelData ? parent.modelData.latestEntry : null
                  }

                  NotificationGroupSection {
                    id: groupedNotificationSection

                    visible: !!parent.modelData && parent.modelData.entryCount > 1
                    width: parent.width
                    group: parent.modelData
                  }
                }
              }
            }
          }

          Column {
            width: parent.width
            spacing: 4
            visible: root.notificationCount > 0

            Controls.Divider {
              horizontalInset: Theme.controlSm / 2
            }

            Controls.PopoverMenuAction {
              width: parent.width
              title: "Clear All"
              onClicked: {
                if (root.notificationCenter) root.notificationCenter.clearEntries();
              }
            }
          }
        }
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

      Patterns.HeroSheetPopover {
        id: wifiMenuPanel

        visible: root.expandedSection === "wifi"
        width: content.width
        x: content.x
        y: content.y + quickTileStack.y + quickTileSection.y
        z: 1
        iconName: "wifi"
        title: root.wifiTileTitle()
        subtitle: root.wifiHeroHint()
        hasStatus: wifiService.ready
        statusActive: wifiService.ready && wifiService.enabled && wifiService.hardwareEnabled
        statusBusy: wifiService.busy
        statusToggleEnabled: wifiService.ready && !wifiService.busy && wifiService.hardwareEnabled
        onStatusClicked: root.toggleWifiEnabled()

        Column {
          width: parent.width
          spacing: Theme.gapMd

          Column {
            width: parent.width
            spacing: Theme.gapXs

            UiText {
              visible: root.wifiLoading && root.initialLoadDeadlineElapsed
              text: "Loading Wi-Fi..."
              size: "xs"
              tone: "subtle"
            }

            UiText {
              visible: !wifiService.hardwareEnabled
              text: "Wi-Fi hardware is blocked."
              size: "xs"
              tone: "accent"
              wrapMode: Text.WordWrap
            }

            UiText {
              visible: wifiService.lastError !== ""
              text: wifiService.lastError
              size: "xs"
              tone: "accent"
              wrapMode: Text.WordWrap
            }
          }

          Column {
            width: parent.width
            spacing: Theme.nudge
            visible: wifiService.ready && wifiService.enabled && wifiService.networks.length > 0

            Repeater {
              model: wifiService.enabled ? Math.min(6, wifiService.networks.length) : 0

              delegate: Controls.PopoverMenuAction {
                id: wifiRow

                required property int index
                readonly property var network: wifiService.networks[index]

                width: parent.width
                visible: !!network
                title: network ? network.ssid : ""
                subtitle: network ? root.wifiNetworkSubtitle(network) : ""
                actionText: network && !network.active ? "Connect" : ""
                trailingIconName: network && network.active ? "check" : ""
                trailingIconColor: Theme.text
                active: network && network.active
                enabled: !!network && !wifiService.busy
                onClicked: root.beginWifiConnect(network)
              }
            }
          }

          UiSurface {
            visible: root.wifiPasswordTarget !== ""
            width: parent.width
            implicitHeight: passwordColumn.implicitHeight + Theme.insetLg
            tone: "panelOverlay"
            outlined: false
            radius: Theme.radiusLg
            border.width: Theme.stroke
            border.color: Qt.rgba(1, 1, 1, 0.08)

            Column {
              id: passwordColumn

              width: parent.width - Theme.insetLg
              anchors.left: parent.left
              anchors.leftMargin: Theme.insetSm
              anchors.top: parent.top
              anchors.topMargin: Theme.insetSm
              spacing: Theme.gapXs

              UiText {
                text: `Password required for ${root.wifiPasswordTarget}`
                size: "xs"
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
              }

              TextField {
                id: wifiPasswordField

                width: parent.width
                height: Theme.controlMd
                echoMode: TextInput.Password
                color: Theme.text
                placeholderText: "Network password"
                placeholderTextColor: Theme.textSubtle
                selectionColor: Theme.selection
                selectedTextColor: Theme.textOnAccent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSm
                onTextChanged: root.wifiPassword = text
                onVisibleChanged: {
                  if (visible) {
                    text = root.wifiPassword;
                    forceActiveFocus();
                  }
                }
                Binding on text {
                  when: !wifiPasswordField.activeFocus
                  value: root.wifiPassword
                }
                background: Rectangle {
                  radius: Theme.radiusMd
                  color: Theme.fieldAlt
                  border.width: Theme.stroke
                  border.color: Theme.divider
                }
              }

              Row {
                spacing: Theme.gapXs

                Controls.Button {
                  text: "Connect"
                  active: true
                  enabled: root.wifiPassword !== "" && !wifiService.busy
                  onClicked: root.submitWifiPassword()
                }

                Controls.Button {
                  text: "Cancel"
                  onClicked: {
                    root.wifiPasswordTarget = "";
                    root.wifiPassword = "";
                  }
                }
              }
            }
          }

          UiText {
            visible: wifiService.ready && wifiService.enabled && wifiService.networks.length === 0 && !wifiService.busy
            text: "No networks available."
            size: "xs"
            tone: "subtle"
          }

          Column {
            width: parent.width
            spacing: 4

            Controls.Divider {
              horizontalInset: Theme.controlSm / 2
            }

            Controls.PopoverMenuAction {
              width: parent.width
              title: wifiService.enabled ? "Turn Off" : "Turn On"
              enabled: wifiService.ready && !wifiService.busy
              onClicked: wifiService.setEnabledState(!wifiService.enabled)
            }

            Controls.PopoverMenuAction {
              width: parent.width
              title: wifiService.busy ? "Refreshing" : "Rescan"
              enabled: wifiService.ready && wifiService.enabled && !wifiService.busy
              onClicked: wifiService.scan()
            }
          }
        }
      }

      Patterns.HeroSheetPopover {
        id: bluetoothMenuPanel

        visible: root.expandedSection === "bluetooth"
        width: content.width
        x: content.x
        y: content.y + quickTileStack.y + quickTileSection.y
        z: 1
        iconName: "bluetooth"
        title: root.bluetoothTileTitle()
        subtitle: root.bluetoothTileSubtitle()
        hasStatus: !!root.bluetoothAdapter
        statusActive: !!(root.bluetoothAdapter && root.bluetoothAdapter.enabled && !root.bluetoothBlocked)
        statusBusy: root.bluetoothBusy
        statusToggleEnabled: !!root.bluetoothAdapter && !root.bluetoothHardBlocked
        onStatusClicked: root.toggleBluetoothEnabled()

        Column {
          width: parent.width
          spacing: Theme.gapMd

          Column {
            width: parent.width
            spacing: Theme.gapXs

            UiText {
              visible: !root.bluetoothAdapter
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
              visible: root.bluetoothLastError !== ""
              text: root.bluetoothLastError
              size: "xs"
              tone: "accent"
              wrapMode: Text.WordWrap
            }
          }

          Column {
            width: parent.width
            spacing: 6
            visible: root.bluetoothAdapter && root.bluetoothAdapter.enabled && root.bluetoothConnectedCount() > 0

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
                model: root.bluetoothAdapter && root.bluetoothAdapter.enabled ? root.bluetoothAdapter.devices : null

                delegate: Controls.PopoverMenuAction {
                  id: connectedDeviceRow

                  required property var modelData
                  readonly property var device: modelData
                  readonly property bool busyState: !!(device && (device.pairing || device.state === BluetoothDeviceState.Connecting))

                  visible: !!(device && device.connected)
                  width: parent.width
                  title: device ? (device.deviceName || device.name || device.address) : ""
                  subtitle: device
                    ? (device.batteryAvailable ? `${Math.round(device.battery)}% battery` : "Connected")
                    : ""
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
            spacing: 6
            visible: root.bluetoothAdapter && root.bluetoothAdapter.enabled && root.bluetoothAvailableCount() > 0

            UiText {
              text: "Available Devices"
              size: "xs"
              tone: "muted"
              font.weight: Font.DemiBold
            }

            Column {
              width: parent.width
              spacing: 4

              Repeater {
                model: root.bluetoothAdapter && root.bluetoothAdapter.enabled ? root.bluetoothAdapter.devices : null

                delegate: Controls.PopoverMenuAction {
                  id: otherDeviceRow

                  required property var modelData
                  readonly property var device: modelData
                  readonly property bool busyState: !!(device && (device.pairing || device.state === BluetoothDeviceState.Connecting))

                  visible: !!(device && !device.connected)
                  width: parent.width
                  title: device ? (device.deviceName || device.name || device.address) : ""
                  subtitle: device ? (device.paired || device.bonded ? "Paired" : "Available") : ""
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

          Column {
            width: parent.width
            spacing: 4

            Controls.Divider {}

            Controls.PopoverMenuAction {
              width: parent.width
              title: root.bluetoothPrimaryActionText()
              enabled: !!root.bluetoothAdapter && !root.bluetoothBusy && !root.bluetoothHardBlocked
              onClicked: root.toggleBluetoothEnabled()
            }

            Controls.PopoverMenuAction {
              width: parent.width
              title: root.bluetoothAdapter && root.bluetoothAdapter.discovering ? "Stop Scan" : "Scan"
              enabled: !!root.bluetoothAdapter && root.bluetoothAdapter.enabled && !root.bluetoothBusy
              onClicked: {
                if (root.bluetoothAdapter) root.bluetoothAdapter.discovering = !root.bluetoothAdapter.discovering;
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
