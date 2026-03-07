pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import "theme"
import "ui/primitives"
import "ui/controls" as Controls
import "ui/patterns" as Patterns

FocusScope {
  id: root

  signal closeRequested()

  implicitWidth: 344
  implicitHeight: panel.implicitHeight

  property string expandedSection: ""
  property string pendingPowerAction: ""
  property string wifiPasswordTarget: ""
  property string wifiPassword: ""
  property bool powerProfileBusy: false
  property real pendingAudioVolume: 0
  property real pendingScreenBrightness: 0
  property bool panelOpen: false
  property bool initialLoadDeadlineElapsed: false
  property int initialLoadDeadlineMs: 50
  readonly property bool powerMenuOpen: expandedSection === "power"
  readonly property bool outputMenuOpen: expandedSection === "outputs"
  readonly property bool selectorPopoverOpen: expandedSection === "profile" || (expandedSection === "lighting" && lightingService.available)
  readonly property bool tileMenuOpen: expandedSection === "wifi" || expandedSection === "bluetooth"
  readonly property bool overlayDismissActive: selectorPopoverOpen || tileMenuOpen || powerMenuOpen || outputMenuOpen
  readonly property var audioSink: Pipewire.defaultAudioSink
  readonly property var audioNode: audioSink && audioSink.audio ? audioSink.audio : null
  readonly property var battery: UPower.displayDevice
  readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
  readonly property bool batteryAvailable: battery && battery.isPresent && battery.isLaptopBattery
  readonly property bool audioReady: audioService.ready
  readonly property bool audioLoading: panelOpen && !audioService.settled
  readonly property bool brightnessLoading: panelOpen && !brightnessService.settled
  readonly property bool wifiLoading: panelOpen && !wifiService.ready

  Component.onCompleted: {
    refreshPanelData();
    panelRefreshTimer.restart();
  }

  function clamp(value, minValue, maxValue) {
    return Math.max(minValue, Math.min(maxValue, value));
  }

  function toggleSection(section) {
    expandedSection = expandedSection === section ? "" : section;
    if (expandedSection !== "wifi") {
      wifiPasswordTarget = "";
      wifiPassword = "";
    }
    if (expandedSection !== "power") pendingPowerAction = "";
    if (expandedSection === "wifi") wifiService.refresh();
    if (expandedSection !== "bluetooth" && bluetoothAdapter) bluetoothAdapter.discovering = false;
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

  function profileLabel(profile) {
    if (profile === PowerProfile.PowerSaver) return "Power Saver";
    if (profile === PowerProfile.Performance) return "Performance";
    return "Balanced";
  }

  function batteryStateLabel(state) {
    if (state === UPowerDeviceState.Charging || state === UPowerDeviceState.PendingCharge) return "Charging";
    if (state === UPowerDeviceState.Discharging || state === UPowerDeviceState.PendingDischarge) return "Discharging";
    if (state === UPowerDeviceState.FullyCharged) return "Full";
    if (state === UPowerDeviceState.Empty) return "Empty";
    return "Unknown";
  }

  function formatDuration(seconds) {
    const totalMinutes = Math.round(Number(seconds || 0) / 60);
    if (totalMinutes <= 0) return "";

    const hours = Math.floor(totalMinutes / 60);
    const minutes = totalMinutes % 60;
    if (hours <= 0) return `${minutes}m`;
    if (minutes <= 0) return `${hours}h`;
    return `${hours}h ${minutes}m`;
  }

  function batterySummary() {
    if (!batteryAvailable) return "No battery";

    const rawPercent = Number(battery.percentage || 0);
    const scaledPercent = rawPercent <= 1.5 ? rawPercent * 100 : rawPercent;
    const percent = `${Math.round(scaledPercent)}%`;
    const state = battery.state;

    if (state === UPowerDeviceState.FullyCharged) return `${percent} Full`;
    if (state === UPowerDeviceState.Charging || state === UPowerDeviceState.PendingCharge) return `${percent} Charging`;
    if (state === UPowerDeviceState.Empty) return `${percent} Empty`;
    return percent;
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
    if (sessionActions.busyAction !== "") return normalizePowerAction(sessionActions.busyAction);
    return pendingPowerAction !== "" ? pendingPowerAction : "shutdown";
  }

  function powerHeroHint() {
    if (sessionActions.busyAction !== "") return `${powerActionTitle(sessionActions.busyAction)} in progress...`;
    if (pendingPowerAction !== "") return "Press the highlighted action again to confirm";
    return "";
  }

  function wifiSummary() {
    if (!wifiService.hardwareEnabled) return "Blocked";
    if (!wifiService.enabled) return "Off";
    if (wifiService.connectedSsid !== "") {
      return `${wifiService.connectedSsid} ${wifiService.connectedSignal}%`;
    }
    if (wifiService.networks.length > 0) return `${wifiService.networks.length} networks`;
    return "On";
  }

  function bluetoothSummary() {
    if (!bluetoothAdapter) return "Unavailable";
    if (bluetoothAdapter.state === BluetoothAdapterState.Blocked) return "Blocked";
    if (!bluetoothAdapter.enabled) return "Off";
    return bluetoothAdapter.discovering ? "Scanning" : "On";
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

  function bluetoothTileTitle() {
    const count = bluetoothConnectedCount();
    if (count > 0) return count === 1 ? "1 Device" : `${count} Devices`;
    return "Bluetooth";
  }

  function bluetoothTileSubtitle() {
    if (!bluetoothAdapter) return "Unavailable";
    if (bluetoothAdapter.state === BluetoothAdapterState.Blocked) return "Blocked";
    if (!bluetoothAdapter.enabled) return "Off";
    return bluetoothAdapter.discovering ? "Scanning" : "Ready";
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

  function triggerPowerAction(action) {
    if (pendingPowerAction === action) {
      pendingPowerAction = "";
      if (action === "logout") sessionActions.logout();
      else if (action === "restart") sessionActions.restart();
      else if (action === "shutdown") sessionActions.shutdown();
      return;
    }

    pendingPowerAction = action;
    powerConfirmTimer.restart();
  }

  function powerActionLabel(action, label) {
    return pendingPowerAction === action ? `Confirm ${label}` : label;
  }

  function toggleWifiEnabled() {
    wifiService.setEnabledState(!wifiService.enabled);
  }

  function toggleBluetoothEnabled() {
    if (!bluetoothAdapter || bluetoothAdapter.state === BluetoothAdapterState.Blocked) return;
    bluetoothAdapter.enabled = !bluetoothAdapter.enabled;
    if (!bluetoothAdapter.enabled) bluetoothAdapter.discovering = false;
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
      pendingPowerAction = "";
      wifiPasswordTarget = "";
      wifiPassword = "";
      if (bluetoothAdapter) bluetoothAdapter.discovering = false;
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

      onExited: function(exitCode) {
        audioService.settled = true;
        audioService.lastError = exitCode === 0 ? "" : String(audioReadStderr.text || "").trim();
        if (exitCode === 0) audioService.parseState(audioReadStdout.text);
        else audioService.ready = false;
      }
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

      onExited: function(exitCode) {
        audioService.lastError = exitCode === 0 ? "" : String(audioWriteStderr.text || "").trim();
        audioRefreshTimer.restart();
      }
    }

    Process {
      id: muteProcess

      stderr: audioMuteStderr

      onExited: function(exitCode) {
        audioService.lastError = exitCode === 0 ? "" : String(audioMuteStderr.text || "").trim();
        audioRefreshTimer.restart();
      }
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

  SessionActions {
    id: sessionActions
  }

  StdioCollector {
    id: powerProfileWriteStderr
    waitForEnd: true
  }

  Process {
    id: powerProfileWriteProcess

    stderr: powerProfileWriteStderr

    onExited: function(exitCode) {
      root.powerProfileBusy = false;
    }
  }

  component StatusChip: UiSurface {
    id: chip

    property string text: ""
    property string iconName: ""

    implicitWidth: chipRow.implicitWidth + 24
    implicitHeight: 40
    tone: "field"
    outlined: false
    radius: 20

    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.08)

    Row {
      id: chipRow

      anchors.centerIn: parent
      spacing: chip.iconName === "" ? 0 : 8

      UiIcon {
        visible: chip.iconName !== ""
        anchors.verticalCenter: parent.verticalCenter
        name: chip.iconName
        strokeColor: Theme.textMuted
      }

      UiText {
        id: chipLabel

        anchors.verticalCenter: parent.verticalCenter
        text: chip.text
        size: "sm"
        tone: "primary"
        font.weight: Font.DemiBold
      }
    }
  }

  component PopoverSurface: UiSurface {
    id: popover

    default property alias content: popoverColumn.data
    property int horizontalPadding: 10
    property int verticalPadding: 10

    width: implicitWidth
    height: implicitHeight
    implicitWidth: 196
    implicitHeight: popoverColumn.implicitHeight + verticalPadding * 2
    tone: "submenu"
    outlined: false
    radius: 18
    z: 8
    clip: true

    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.08)

    Column {
      id: popoverColumn

      width: parent.width - popover.horizontalPadding * 2
      anchors.left: parent.left
      anchors.leftMargin: popover.horizontalPadding
      anchors.top: parent.top
      anchors.topMargin: popover.verticalPadding
      spacing: 2
    }
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

      onExited: function(exitCode) {
        brightnessController.lastError = exitCode === 0 ? "" : String(detectStderr.text || "").trim();
        if (exitCode === 0) brightnessController.parseDeviceList(detectStdout.text);
        else brightnessController.settled = true;
      }
    }

    StdioCollector {
      id: screenStdout
      waitForEnd: true
    }

    Process {
      id: screenReadProcess
      stdout: screenStdout
      onExited: function(exitCode) {
        brightnessController.settled = true;
        if (exitCode === 0) brightnessController.parseBrightness(screenStdout.text, false);
      }
    }

    StdioCollector {
      id: keyboardStdout
      waitForEnd: true
    }

    Process {
      id: keyboardReadProcess
      stdout: keyboardStdout
      onExited: function(exitCode) {
        if (exitCode === 0) brightnessController.parseBrightness(keyboardStdout.text, true);
      }
    }

    StdioCollector {
      id: screenWriteStderr
      waitForEnd: true
    }

    Process {
      id: screenWriteProcess
      stderr: screenWriteStderr
      onExited: function(exitCode) {
        brightnessController.lastError = exitCode === 0 ? "" : String(screenWriteStderr.text || "").trim();
        brightnessController.refreshScreen();
      }
    }

    StdioCollector {
      id: keyboardWriteStderr
      waitForEnd: true
    }

    Process {
      id: keyboardWriteProcess
      stderr: keyboardWriteStderr
      onExited: function(exitCode) {
        brightnessController.lastError = exitCode === 0 ? "" : String(keyboardWriteStderr.text || "").trim();
        brightnessController.refreshKeyboard();
      }
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

      onExited: function(exitCode) {
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
      }
    }

    StdioCollector {
      id: lightingWriteStderr
      waitForEnd: true
    }

    Process {
      id: lightingWriteProcess

      stderr: lightingWriteStderr

      onExited: function(exitCode) {
        lightingController.lastError = exitCode === 0 ? "" : String(lightingWriteStderr.text || "").trim();
        lightingRefreshTimer.restart();
      }
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

      onExited: function(exitCode) {
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
      }
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
      onExited: function(exitCode) {
        wifiController.lastError = exitCode === 0 ? "" : String(wifiToggleStderr.text || "").trim();
        wifiController.refresh();
      }
    }

    Process {
      id: scanProcess
      stderr: wifiScanStderr
      onExited: function(exitCode) {
        wifiController.lastError = exitCode === 0 ? "" : String(wifiScanStderr.text || "").trim();
        wifiRescanDelay.restart();
      }
    }

    Process {
      id: connectProcess
      stderr: wifiConnectStderr
      onExited: function(exitCode) {
        wifiController.lastError = exitCode === 0 ? "" : String(wifiConnectStderr.text || "").trim();
        if (exitCode !== 0) wifiController.busy = false;
        wifiController.pendingSsid = "";
        wifiRescanDelay.restart();
      }
    }

    Timer {
      id: wifiRescanDelay
      interval: 700
      repeat: false
      onTriggered: wifiController.refresh()
    }
  }

  component SessionActions: Item {
    id: sessionActionsController

    property string busyAction: ""
    property string lastError: ""

    function runAction(name, command) {
      busyAction = name;
      lastError = "";
      actionProcess.exec(command);
    }

    function lock() {
      lockProcess.command = ["swaylock"];
      lockProcess.startDetached();
      lastError = "";
    }

    function sleep() {
      runAction("sleep", ["systemctl", "suspend"]);
    }

    function restart() {
      runAction("restart", ["systemctl", "reboot"]);
    }

    function shutdown() {
      runAction("shutdown", ["systemctl", "poweroff"]);
    }

    function logout() {
      runAction("logout", [
        "sh",
        "-lc",
        "if [ -n \"$XDG_SESSION_ID\" ]; then exec loginctl terminate-session \"$XDG_SESSION_ID\"; fi; session=\"$(loginctl show-user \"$USER\" -p Display --value 2>/dev/null)\"; if [ -n \"$session\" ]; then exec loginctl terminate-session \"$session\"; fi; printf 'Unable to determine current session.\n' >&2; exit 1"
      ]);
    }

    StdioCollector {
      id: actionStderr
      waitForEnd: true
    }

    Process {
      id: actionProcess

      stderr: actionStderr

      onExited: function(exitCode) {
        sessionActionsController.lastError = exitCode === 0 ? "" : String(actionStderr.text || "").trim();
        sessionActionsController.busyAction = "";
      }
    }

    Process {
      id: lockProcess
    }
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
    implicitHeight: content.implicitHeight + 32
    tone: "panelOverlay"
    outlined: false
    radius: 30

    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.12)

    MouseArea {
      anchors.fill: parent
    }

    Column {
      id: content

      width: parent.width - 32
      anchors.left: parent.left
      anchors.leftMargin: 16
      anchors.top: parent.top
      anchors.topMargin: 16
      spacing: 12

      Row {
        width: parent.width - 8
        anchors.horizontalCenter: parent.horizontalCenter
        height: 48
        spacing: 12

        StatusChip {
          id: batteryChip
          visible: root.batteryAvailable
          anchors.verticalCenter: parent.verticalCenter
          iconName: root.batteryIconName()
          text: root.batterySummary()
        }

        Item {
          width: Math.max(0, parent.width - (batteryChip.visible ? batteryChip.implicitWidth : 0) - lockButton.implicitWidth - powerToggleButton.implicitWidth - 24)
          height: parent.height
        }

        Controls.IconButton {
          id: lockButton
          anchors.verticalCenter: parent.verticalCenter
          circular: true
          iconName: "lock"
          onClicked: sessionActions.lock()
        }

        Controls.IconButton {
          id: powerToggleButton
          anchors.verticalCenter: parent.verticalCenter
          circular: true
          iconName: "power"
          active: root.expandedSection === "power"
          onClicked: root.toggleSection("power")
        }
      }

      Item {
        id: powerPopoverSpacer

        width: parent.width
        height: root.powerMenuOpen ? powerPopover.implicitHeight : 0
      }

      Row {
        width: parent.width
        height: 40
        spacing: 0

        Controls.Slider {
          width: parent.width
          anchors.verticalCenter: parent.verticalCenter
          showIcon: false
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
              iconSize: 18
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
        height: 40
        spacing: 0

        Controls.Slider {
          id: brightnessSlider

          width: parent.width
          anchors.verticalCenter: parent.verticalCenter
          showIcon: false
          trailingSlotWidth: Theme.controlAccessorySlot
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
              enabled: lightingService.available
              useActiveStyling: true
              open: root.expandedSection === "lighting"
              onClicked: root.toggleSection("lighting")
            }
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

      UiSurface {
        id: outputsPopover

        visible: root.outputMenuOpen
        width: content.width
        x: content.x
        y: content.y + outputsPopoverSpacer.y
        z: 1
        implicitHeight: outputsColumn.implicitHeight + 20
        tone: "submenu"
        outlined: false
        radius: 18
        border.width: 1
        border.color: Theme.divider

        Column {
          id: outputsColumn

          width: parent.width - 20
          anchors.left: parent.left
          anchors.leftMargin: 10
          anchors.top: parent.top
          anchors.topMargin: 10
          spacing: 8

          UiText {
            text: "Sound Output"
            size: "sm"
            font.weight: Font.DemiBold
          }

          Controls.Menu {
            width: parent.width

            Repeater {
              model: Pipewire.nodes

              delegate: Controls.MenuItem {
                id: outputRow

                required property var modelData
                readonly property var outputNode: modelData
                readonly property bool shown: !!(outputNode && outputNode.audio && outputNode.isSink && !outputNode.isStream)

                visible: shown
                width: parent.width
                implicitHeight: shown ? 44 : 0
                height: shown ? implicitHeight : 0
                iconName: "speaker"
                title: root.outputLabel(outputRow.outputNode)
                trailingIconName: root.audioSink === outputRow.outputNode ? "check" : ""
                active: root.audioSink === outputRow.outputNode
                compact: true
                onClicked: Pipewire.preferredDefaultAudioSink = outputRow.outputNode
              }
            }
          }
        }
      }

      UiSurface {
        id: powerPopover

        visible: root.powerMenuOpen
        width: content.width
        x: content.x
        y: content.y + powerPopoverSpacer.y
        z: 1
        implicitHeight: powerColumn.implicitHeight + 28
        tone: "submenu"
        outlined: false
        radius: 24
        color: Qt.darker(Theme.submenu, 1.06)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)

        Column {
          id: powerColumn

          width: parent.width - 32
          anchors.left: parent.left
          anchors.leftMargin: 16
          anchors.top: parent.top
          anchors.topMargin: 16
          spacing: 14

          Row {
            width: parent.width
            spacing: 12

            Rectangle {
              width: 52
              height: 52
              radius: 26
              color: "#f2f4f7"

              UiIcon {
                anchors.centerIn: parent
                name: root.powerActionIcon(root.powerHeroAction())
                strokeColor: Theme.panelOverlay
                stroke: 2.1
              }
            }

            Column {
              width: Math.max(0, parent.width - 64)
              anchors.verticalCenter: parent.verticalCenter
              spacing: 2

              UiText {
                width: parent.width
                text: root.powerActionTitle(root.powerHeroAction())
                size: "lg"
                font.weight: Font.Bold
                elide: Text.ElideRight
              }

              UiText {
                width: parent.width
                visible: root.powerHeroHint() !== ""
                text: root.powerHeroHint()
                size: "xs"
                tone: "subtle"
                wrapMode: Text.WordWrap
              }
            }
          }

          Column {
            width: parent.width
            spacing: 2

            Controls.MenuItem {
              width: parent.width
              iconName: ""
              title: "Lock"
              compact: true
              onClicked: sessionActions.lock()
            }

            Controls.MenuItem {
              width: parent.width
              iconName: ""
              title: "Suspend"
              compact: true
              onClicked: sessionActions.sleep()
            }

            Controls.MenuItem {
              width: parent.width
              iconName: ""
              title: "Restart"
              compact: true
              activeStyle: "subtle"
              actionText: root.pendingPowerAction === "restart" ? "Confirm" : ""
              actionTextOnHover: false
              active: root.pendingPowerAction === "restart"
              onClicked: root.triggerPowerAction("restart")
            }

            Controls.MenuItem {
              width: parent.width
              iconName: ""
              title: "Power Off"
              compact: true
              activeStyle: "subtle"
              actionText: root.pendingPowerAction === "shutdown" ? "Confirm" : ""
              actionTextOnHover: false
              active: root.pendingPowerAction === "shutdown"
              onClicked: root.triggerPowerAction("shutdown")
            }

            Controls.MenuItem {
              width: parent.width
              iconName: ""
              title: "Log Out"
              compact: true
              activeStyle: "subtle"
              actionText: root.pendingPowerAction === "logout" ? "Confirm" : ""
              actionTextOnHover: false
              active: root.pendingPowerAction === "logout"
              onClicked: root.triggerPowerAction("logout")
            }
          }

          UiText {
            visible: sessionActions.lastError !== ""
            text: sessionActions.lastError
            size: "xs"
            tone: "accent"
            wrapMode: Text.WordWrap
          }
        }
      }

      Patterns.QuickTileMenuPanel {
        id: wifiMenuPanel

        visible: root.expandedSection === "wifi"
        width: content.width
        x: content.x
        y: content.y + quickTileStack.y + quickTileSection.y
        z: 1
        iconName: "wifi"
        title: root.wifiTileTitle()

        UiText {
          width: parent.width
          visible: root.wifiHeroHint() !== ""
          text: root.wifiHeroHint()
          size: "xs"
          tone: "subtle"
          wrapMode: Text.WordWrap
        }

        UiText {
          visible: root.wifiLoading && root.initialLoadDeadlineElapsed
          text: "Loading Wi-Fi..."
          size: "xs"
          tone: "subtle"
        }

        UiText {
          visible: !wifiService.hardwareEnabled
          text: "WiFi hardware is blocked."
          size: "xs"
          tone: "accent"
        }

        Controls.Menu {
          id: wifiNetworksMenu

          width: parent.width
          visible: wifiService.ready && wifiService.enabled && wifiService.networks.length > 0

          Repeater {
            model: wifiService.enabled ? Math.min(6, wifiService.networks.length) : 0

            delegate: Controls.MenuItem {
              id: wifiRow

              required property int index
              readonly property var network: wifiService.networks[index]

              width: wifiNetworksMenu.width
              implicitHeight: 52
              height: implicitHeight
              iconName: "wifi"
              title: wifiRow.network ? wifiRow.network.ssid : ""
              subtitle: wifiRow.network
                ? `${wifiRow.network.signal}%${wifiRow.network.security !== "" ? `, ${wifiRow.network.security}` : ", open"}${wifiRow.network.known ? ", saved" : ""}`
                : ""
              actionText: wifiRow.network && !wifiRow.network.active ? "Connect" : ""
              trailingIconName: wifiRow.network && wifiRow.network.active ? "check" : ""
              active: wifiRow.network && wifiRow.network.active
              activeStyle: "subtle"
              enabled: !!wifiRow.network && !wifiService.busy
              onClicked: root.beginWifiConnect(wifiRow.network)
            }
          }
        }

        UiSurface {
          visible: root.wifiPasswordTarget !== ""
          width: parent.width
          implicitHeight: passwordColumn.implicitHeight + 20
          tone: "panelOverlay"
          outlined: false
          radius: 16
          border.width: 1
          border.color: Theme.divider

          Column {
            id: passwordColumn

            width: parent.width - 20
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.top: parent.top
            anchors.topMargin: 10
            spacing: 8

            UiText {
              text: `Password required for ${root.wifiPasswordTarget}`
              size: "xs"
              font.weight: Font.DemiBold
              wrapMode: Text.WordWrap
            }

            TextField {
              id: wifiPasswordField

              width: parent.width
              height: 38
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
                radius: 14
                color: Theme.fieldAlt
                border.width: 1
                border.color: Theme.divider
              }
            }

            Row {
              spacing: 8

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

        UiText {
          visible: wifiService.lastError !== ""
          text: wifiService.lastError
          size: "xs"
          tone: "accent"
          wrapMode: Text.WordWrap
        }

        Row {
          width: parent.width
          spacing: 8

          Controls.Button {
            text: wifiService.enabled ? "Turn Off" : "Turn On"
            enabled: wifiService.ready
            onClicked: wifiService.setEnabledState(!wifiService.enabled)
          }

          Controls.Button {
            text: wifiService.busy ? "Refreshing" : "Rescan"
            enabled: wifiService.ready && wifiService.enabled && !wifiService.busy
            onClicked: wifiService.scan()
          }
        }
      }

      Patterns.QuickTileMenuPanel {
        id: bluetoothMenuPanel

        visible: root.expandedSection === "bluetooth"
        width: content.width
        x: content.x
        y: content.y + quickTileStack.y + quickTileSection.y
        z: 1
        iconName: "bluetooth"
        title: root.bluetoothTileTitle()

        UiText {
          width: parent.width
          visible: root.bluetoothTileSubtitle() !== ""
          text: root.bluetoothTileSubtitle()
          size: "xs"
          tone: "subtle"
          wrapMode: Text.WordWrap
        }

        UiText {
          visible: !root.bluetoothAdapter
          text: "No Bluetooth adapter found."
          size: "xs"
          tone: "accent"
        }

        UiText {
          visible: !!root.bluetoothAdapter && root.bluetoothAdapter.state === BluetoothAdapterState.Blocked
          text: "Bluetooth is blocked by hardware or rfkill."
          size: "xs"
          tone: "accent"
        }

        UiText {
          visible: root.bluetoothAdapter && root.bluetoothAdapter.enabled && root.bluetoothConnectedCount() > 0
          text: "Connected Devices"
          size: "xs"
          tone: "muted"
          font.weight: Font.DemiBold
        }

        Controls.Menu {
          id: bluetoothConnectedMenu

          width: parent.width
          visible: root.bluetoothAdapter && root.bluetoothAdapter.enabled && root.bluetoothConnectedCount() > 0

          Repeater {
            model: root.bluetoothAdapter && root.bluetoothAdapter.enabled ? root.bluetoothAdapter.devices : null

            delegate: Controls.MenuItem {
              id: connectedDeviceRow

              required property int index
              required property var modelData
              readonly property var device: modelData
              readonly property bool busyState: !!(device && (device.pairing || device.state === BluetoothDeviceState.Connecting))
              readonly property bool hasNextVisible: {
                if (!root.bluetoothAdapter || !root.bluetoothAdapter.devices) return false;
                for (let i = index + 1; i < root.bluetoothAdapter.devices.count; i += 1) {
                  const nextDevice = root.bluetoothAdapter.devices.get(i);
                  if (nextDevice && nextDevice.connected) return true;
                }
                return false;
              }

              visible: device && device.connected
              width: bluetoothConnectedMenu.width
              implicitHeight: visible ? 52 : 0
              height: visible ? implicitHeight : 0
              iconName: "bluetooth"
              title: connectedDeviceRow.device.deviceName || connectedDeviceRow.device.name || connectedDeviceRow.device.address
              subtitle: connectedDeviceRow.device.batteryAvailable
                ? `${Math.round(connectedDeviceRow.device.battery)}% battery`
                : "Connected"
              actionText: connectedDeviceRow.busyState ? "Working" : "Disconnect"
              active: true
              dividerVisible: visible && hasNextVisible
              enabled: visible && !connectedDeviceRow.busyState
              onClicked: {
                if (connectedDeviceRow.busyState) return;
                connectedDeviceRow.device.disconnect();
              }
            }
          }
        }

        UiText {
          visible: root.bluetoothAdapter && root.bluetoothAdapter.enabled && root.bluetoothAvailableCount() > 0
          text: "Available Devices"
          size: "xs"
          tone: "muted"
          font.weight: Font.DemiBold
        }

        Controls.Menu {
          id: bluetoothAvailableMenu

          width: parent.width
          visible: root.bluetoothAdapter && root.bluetoothAdapter.enabled && root.bluetoothAvailableCount() > 0

          Repeater {
            model: root.bluetoothAdapter && root.bluetoothAdapter.enabled ? root.bluetoothAdapter.devices : null

            delegate: Controls.MenuItem {
              id: otherDeviceRow

              required property int index
              required property var modelData
              readonly property var device: modelData
              readonly property bool busyState: !!(device && (device.pairing || device.state === BluetoothDeviceState.Connecting))
              readonly property bool hasNextVisible: {
                if (!root.bluetoothAdapter || !root.bluetoothAdapter.devices) return false;
                for (let i = index + 1; i < root.bluetoothAdapter.devices.count; i += 1) {
                  const nextDevice = root.bluetoothAdapter.devices.get(i);
                  if (nextDevice && !nextDevice.connected) return true;
                }
                return false;
              }

              visible: device && !device.connected
              width: bluetoothAvailableMenu.width
              implicitHeight: visible ? 52 : 0
              height: visible ? implicitHeight : 0
              iconName: "bluetooth"
              title: otherDeviceRow.device.deviceName || otherDeviceRow.device.name || otherDeviceRow.device.address
              subtitle: otherDeviceRow.device.paired || otherDeviceRow.device.bonded ? "Paired" : "Available"
              actionText: otherDeviceRow.busyState
                ? "Working"
                : (otherDeviceRow.device.paired || otherDeviceRow.device.bonded ? "Connect" : "Pair")
              dividerVisible: visible && hasNextVisible
              enabled: visible && !otherDeviceRow.busyState
              onClicked: {
                if (otherDeviceRow.busyState) return;
                if (otherDeviceRow.device.paired || otherDeviceRow.device.bonded) otherDeviceRow.device.connect();
                else otherDeviceRow.device.pair();
              }
            }
          }
        }

        Row {
          width: parent.width
          spacing: 8

          Controls.Button {
            text: root.bluetoothAdapter && root.bluetoothAdapter.enabled ? "Turn Off" : "Turn On"
            enabled: !!root.bluetoothAdapter && root.bluetoothAdapter.state !== BluetoothAdapterState.Blocked
            onClicked: root.toggleBluetoothEnabled()
          }

          Controls.Button {
            text: root.bluetoothAdapter && root.bluetoothAdapter.discovering ? "Stop Scan" : "Scan"
            enabled: !!root.bluetoothAdapter && root.bluetoothAdapter.enabled
            onClicked: {
              if (root.bluetoothAdapter) root.bluetoothAdapter.discovering = !root.bluetoothAdapter.discovering;
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
        anchors.fill: panel
        enabled: root.selectorPopoverOpen
        onClicked: root.dismissOverlaySection()
      }

      PopoverSurface {
        id: profilePopover
        visible: root.expandedSection === "profile"
        width: implicitWidth
        x: root.popupX(profileTile, width, false)
        y: root.popupOverlayY(profileTile, height)

        Controls.MenuItem {
          width: parent.width
          iconName: "gauge"
          title: "Performance"
          trailingIconName: PowerProfiles.profile === PowerProfile.Performance ? "check" : ""
          active: PowerProfiles.profile === PowerProfile.Performance
          activeStyle: "indicator"
          compact: true
          dividerVisible: true
          enabled: PowerProfiles.hasPerformanceProfile && !root.powerProfileBusy
          onClicked: root.selectPowerProfile(PowerProfile.Performance)
        }

        Controls.MenuItem {
          width: parent.width
          iconName: "gauge"
          title: "Balanced"
          trailingIconName: PowerProfiles.profile === PowerProfile.Balanced ? "check" : ""
          active: PowerProfiles.profile === PowerProfile.Balanced
          activeStyle: "indicator"
          compact: true
          dividerVisible: true
          enabled: !root.powerProfileBusy
          onClicked: root.selectPowerProfile(PowerProfile.Balanced)
        }

        Controls.MenuItem {
          width: parent.width
          iconName: "gauge"
          title: "Power Saver"
          trailingIconName: PowerProfiles.profile === PowerProfile.PowerSaver ? "check" : ""
          active: PowerProfiles.profile === PowerProfile.PowerSaver
          activeStyle: "indicator"
          compact: true
          enabled: !root.powerProfileBusy
          onClicked: root.selectPowerProfile(PowerProfile.PowerSaver)
        }
      }

      PopoverSurface {
        visible: root.expandedSection === "lighting" && lightingService.available
        width: lightingTile.width
        x: root.popupX(lightingTile, width, false)
        y: root.popupOverlayY(lightingTile, height)

        Controls.MenuItem {
          width: parent.width
          iconName: "sun"
          title: "Off"
          trailingIconName: root.lightingLevelIndex() === 0 ? "check" : ""
          active: root.lightingLevelIndex() === 0
          activeStyle: "indicator"
          compact: true
          dividerVisible: true
          onClicked: root.setLightingLevel(0)
        }

        Controls.MenuItem {
          width: parent.width
          iconName: "sun"
          title: "Low"
          trailingIconName: root.lightingLevelIndex() === 1 ? "check" : ""
          active: root.lightingLevelIndex() === 1
          activeStyle: "indicator"
          compact: true
          dividerVisible: true
          onClicked: root.setLightingLevel(1)
        }

        Controls.MenuItem {
          width: parent.width
          iconName: "sun"
          title: "Medium"
          trailingIconName: root.lightingLevelIndex() === 2 ? "check" : ""
          active: root.lightingLevelIndex() === 2
          activeStyle: "indicator"
          compact: true
          dividerVisible: true
          onClicked: root.setLightingLevel(2)
        }

        Controls.MenuItem {
          width: parent.width
          iconName: "sun"
          title: "High"
          trailingIconName: root.lightingLevelIndex() === 3 ? "check" : ""
          active: root.lightingLevelIndex() === 3
          activeStyle: "indicator"
          compact: true
          onClicked: root.setLightingLevel(3)
        }
      }

    }
  }
}
