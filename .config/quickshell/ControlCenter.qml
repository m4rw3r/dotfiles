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

  implicitWidth: 332
  implicitHeight: panel.implicitHeight

  property string expandedSection: ""
  property string pendingPowerAction: ""
  property string wifiPasswordTarget: ""
  property string wifiPassword: ""
  property real pendingAudioVolume: 0
  property real pendingScreenBrightness: 0
  property bool panelOpen: false
  property bool hasInitialSnapshot: false
  readonly property var audioSink: Pipewire.defaultAudioSink
  readonly property var audioNode: audioSink && audioSink.audio ? audioSink.audio : null
  readonly property var battery: UPower.displayDevice
  readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
  readonly property bool batteryAvailable: battery && battery.isPresent && battery.isLaptopBattery
  readonly property bool audioReady: audioService.ready
  readonly property bool panelDataReady: audioService.ready && brightnessService.screenLoaded && wifiService.ready

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
    if (!anchorItem) return 0;
    const position = anchorItem.mapToItem(panel, 0, 0);
    return position.y + anchorItem.height + (spacing || 8);
  }

  function popupCenteredX(anchorItem, popupWidth) {
    if (!anchorItem || !panel) return 0;
    const position = anchorItem.mapToItem(panel, 0, 0);
    const maxX = Math.max(0, panel.width - popupWidth);
    const rawX = position.x + (anchorItem.width - popupWidth) / 2;
    return clamp(rawX, 0, maxX);
  }

  function popupAboveY(anchorItem, popupHeight, spacing) {
    if (!anchorItem || !panel) return 0;
    const position = anchorItem.mapToItem(panel, 0, 0);
    return position.y + (anchorItem.height - popupHeight) / 2 - (spacing || 0);
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
    if (!wifiService.enabled || wifiService.connectedSsid === "") return "Wi-Fi";
    return wifiService.connectedSsid;
  }

  function wifiTileSubtitle() {
    if (!wifiService.hardwareEnabled) return "Blocked";
    if (!wifiService.enabled) return "Off";
    if (wifiService.connectedSsid !== "") return `${wifiService.connectedSignal}%`;
    return wifiService.networks.length > 0 ? `${wifiService.networks.length} networks` : "Available";
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
    if (PowerProfiles.profile === PowerProfile.PowerSaver) return "Saver";
    if (PowerProfiles.profile === PowerProfile.Performance) return "Performance";
    return "Balanced";
  }

  function selectPowerProfile(profile) {
    PowerProfiles.profile = profile;
    expandedSection = "";
  }

  function keyboardTileTitle() {
    return keyboardLevelLabel(keyboardLevelIndex());
  }

  function keyboardTileSubtitle() {
    return brightnessService.keyboardAvailable ? "Keyboard Backlight" : "Unavailable";
  }

  function keyboardPresetValue(index) {
    const maximum = Math.max(1, Number(brightnessService.keyboardMax) || 1);
    if (index <= 0) return 0;
    if (index === 1) return Math.max(1, Math.round(maximum / 3));
    if (index === 2) return Math.max(1, Math.round((maximum * 2) / 3));
    return maximum;
  }

  function keyboardLevelIndex() {
    if (!brightnessService.keyboardAvailable) return 0;

    const currentValue = Math.max(0, Math.round(Number(brightnessService.keyboardValue) || 0));
    let nearestIndex = 0;
    let nearestDistance = Number.MAX_VALUE;

    for (let index = 0; index < 4; index += 1) {
      const distance = Math.abs(currentValue - keyboardPresetValue(index));
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    }

    return nearestIndex;
  }

  function keyboardLevelLabel(index) {
    if (index === 3) return "High";
    if (index === 2) return "Med";
    if (index === 1) return "Low";
    return "Off";
  }

  function setKeyboardLevel(index) {
    if (!brightnessService.keyboardAvailable) return;
    brightnessService.applyKeyboardValue(keyboardPresetValue(index));
  }

  function cycleKeyboardBacklight() {
    if (!brightnessService.keyboardAvailable) return;
    setKeyboardLevel((keyboardLevelIndex() + 1) % 4);
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

  function cyclePowerProfile() {
    if (PowerProfiles.profile === PowerProfile.PowerSaver) {
      PowerProfiles.profile = PowerProfile.Balanced;
      return;
    }

    if (PowerProfiles.profile === PowerProfile.Balanced) {
      PowerProfiles.profile = PowerProfiles.hasPerformanceProfile ? PowerProfile.Performance : PowerProfile.PowerSaver;
      return;
    }

    PowerProfiles.profile = PowerProfile.PowerSaver;
  }

  onPanelOpenChanged: {
    if (panelOpen) {
      forceActiveFocus();
      refreshPanelData();
      panelRefreshTimer.restart();
    } else {
      expandedSection = "";
      pendingPowerAction = "";
      wifiPasswordTarget = "";
      wifiPassword = "";
      if (bluetoothAdapter) bluetoothAdapter.discovering = false;
    }
  }

  onPanelDataReadyChanged: {
    if (!panelDataReady) return;
    hasInitialSnapshot = true;
  }

  Keys.onEscapePressed: root.closeRequested()

  Timer {
    id: powerConfirmTimer
    interval: 2200
    repeat: false
    onTriggered: root.pendingPowerAction = ""
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

  Item {
    id: audioService

    property real volume: 0
    property bool muted: false
    property bool ready: false
    property string lastError: ""

    function refresh() {
      readProcess.exec(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]);
    }

    function setVolume(nextVolume) {
      const clamped = Math.max(0, Math.min(1.5, Number(nextVolume)));
      volume = clamped;
      if (clamped > 0 && muted) muted = false;
      writeProcess.exec(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", clamped.toFixed(3)]);
    }

    function setMuted(nextMuted) {
      muted = nextMuted;
      muteProcess.exec(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", nextMuted ? "1" : "0"]);
    }

    function toggleMuted() {
      setMuted(!muted);
    }

    function parseState(text) {
      const match = String(text || "").match(/Volume:\s+([0-9.]+)(?:\s+\[(MUTED)\])?/i);
      if (!match) {
        ready = false;
        return;
      }

      volume = Math.max(0, Math.min(1.5, Number(match[1]) || 0));
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
        audioService.lastError = exitCode === 0 ? "" : String(audioReadStderr.text || "").trim();
        if (exitCode === 0) audioService.parseState(audioReadStdout.text);
      }
    }

    StdioCollector {
      id: audioWriteStderr
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

      stderr: audioWriteStderr

      onExited: function(exitCode) {
        audioService.lastError = exitCode === 0 ? "" : String(audioWriteStderr.text || "").trim();
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

  component FlatButton: Controls.Button {}

  component StatusChip: UiSurface {
    id: chip

    property string text: ""

    implicitWidth: chipLabel.implicitWidth + 32
    implicitHeight: 38
    tone: "chip"
    outlined: false
    radius: 19

    border.width: 1
    border.color: Theme.divider

    UiText {
      id: chipLabel

      anchors.centerIn: parent
      text: chip.text
      size: "sm"
      tone: "muted"
      font.weight: Font.DemiBold
    }
  }

  component IconButton: Controls.IconButton {}

  component CircleIconButton: Controls.IconButton {
    circular: true
  }

  component IconBadge: Controls.IconButton {
    interactive: false
  }

  component QuickTile: Patterns.QuickTile {}

  component MediaSlider: Controls.Slider {}

  component MenuList: Controls.Menu {}

  component PopoverSurface: UiSurface {
    id: popover

    default property alias content: popoverColumn.data
    property int horizontalPadding: 10
    property int verticalPadding: 10

    width: implicitWidth
    implicitWidth: 220
    implicitHeight: popoverColumn.implicitHeight + verticalPadding * 2
    tone: "submenu"
    outlined: false
    radius: 18
    z: 8

    border.width: 1
    border.color: Theme.divider

    Column {
      id: popoverColumn

      width: parent.width - popover.horizontalPadding * 2
      anchors.left: parent.left
      anchors.leftMargin: popover.horizontalPadding
      anchors.top: parent.top
      anchors.topMargin: popover.verticalPadding
      spacing: 8
    }
  }

  component MenuRow: Controls.MenuItem {}

  component BrightnessController: Item {
    id: brightnessController

    property bool ready: false
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
      refreshProcess.exec([
        "sh",
        "-lc",
        "nmcli -t -f WIFI,WIFI-HW general status; printf '\n@@SAVED@@\n'; nmcli -t --escape yes -f NAME,TYPE connection show; printf '\n@@WIFI@@\n'; nmcli -t --escape yes -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan no"
      ]);
    }

    function scan() {
      busy = true;
      scanProcess.exec(["nmcli", "device", "wifi", "rescan"]);
    }

    function setEnabledState(nextState) {
      busy = true;
      toggleProcess.exec(["nmcli", "radio", "wifi", nextState ? "on" : "off"]);
    }

    function connectNetwork(ssid, password) {
      if (ssid === "") return;

      const command = ["nmcli", "device", "wifi", "connect", ssid];
      if (password !== "") command.push("password", password);

      busy = true;
      pendingSsid = ssid;
      connectProcess.exec(command);
    }

    function parseRefresh(text) {
      const blocks = String(text || "").split("\n@@SAVED@@\n");
      const statusBlock = blocks.length > 0 ? blocks[0] : "";
      const remainder = blocks.length > 1 ? blocks[1] : "";
      const savedBlocks = remainder.split("\n@@WIFI@@\n");
      const savedBlock = savedBlocks.length > 0 ? savedBlocks[0] : "";
      const wifiBlock = savedBlocks.length > 1 ? savedBlocks[1] : "";

      parseStatus(statusBlock);
      parseSaved(savedBlock);
      parseWifiList(wifiBlock);
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
        const line = lines[i].trim();
        if (line === "") continue;

        const parts = splitEscaped(line);
        if (parts.length < 2) continue;
        if (parts[1] !== "802-11-wireless") continue;
        if (parts[0] === "") continue;
        known[parts[0]] = true;
      }

      savedNetworks = known;
    }

    function parseWifiList(text) {
      const lines = String(text || "").split("\n");
      const deduped = {};
      let activeSsid = "";
      let activeSignal = 0;

      for (let i = 0; i < lines.length; i += 1) {
        const line = lines[i].trim();
        if (line === "") continue;

        const parts = splitEscaped(line);
        if (parts.length < 4) continue;

        const active = parts[0] === "*";
        const ssid = parts[1];
        const signal = parseInt(parts[2]) || 0;
        const security = parts[3];

        if (ssid === "") continue;

        const network = {
          active,
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

        const existing = deduped[ssid];
        if (!existing || existing.signal < network.signal || (network.active && !existing.active)) {
          deduped[ssid] = network;
        }
      }

      const nextNetworks = Object.values(deduped);
      nextNetworks.sort((left, right) => {
        if (left.active !== right.active) return left.active ? -1 : 1;
        if (left.known !== right.known) return left.known ? -1 : 1;
        if (left.signal !== right.signal) return right.signal - left.signal;
        return left.ssid.localeCompare(right.ssid);
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
        wifiController.lastError = exitCode === 0 ? "" : String(wifiRefreshStderr.text || "").trim();
        if (exitCode === 0) wifiController.parseRefresh(wifiRefreshStdout.text);
      }
    }

    StdioCollector {
      id: wifiActionStderr
      waitForEnd: true
    }

    Process {
      id: toggleProcess
      stderr: wifiActionStderr
      onExited: function(exitCode) {
        wifiController.lastError = exitCode === 0 ? "" : String(wifiActionStderr.text || "").trim();
        wifiController.refresh();
      }
    }

    Process {
      id: scanProcess
      stderr: wifiActionStderr
      onExited: function(exitCode) {
        wifiController.lastError = exitCode === 0 ? "" : String(wifiActionStderr.text || "").trim();
        wifiRescanDelay.restart();
      }
    }

    Process {
      id: connectProcess
      stderr: wifiActionStderr
      onExited: function(exitCode) {
        wifiController.lastError = exitCode === 0 ? "" : String(wifiActionStderr.text || "").trim();
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
        "if [ -n \"$XDG_SESSION_ID\" ]; then exec loginctl terminate-session \"$XDG_SESSION_ID\"; fi; exit 1"
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
    implicitHeight: content.implicitHeight + 28
    tone: "panelOverlay"
    outlined: false
    radius: 28

    border.width: 1
    border.color: Theme.divider

    MouseArea {
      anchors.fill: parent
    }

    TapHandler {
      enabled: root.expandedSection === "profile"
      acceptedButtons: Qt.LeftButton
      onTapped: function(eventPoint) {
        const localPoint = panel.mapToItem(profilePopover, eventPoint.position.x, eventPoint.position.y);
        if (profilePopover.contains(localPoint)) return;
        Qt.callLater(function() {
          if (root.expandedSection === "profile") root.expandedSection = "";
        });
      }
    }

    Column {
      id: content

      visible: !root.panelOpen || root.hasInitialSnapshot || root.panelDataReady
      width: parent.width - 28
      anchors.left: parent.left
      anchors.leftMargin: 14
      anchors.top: parent.top
      anchors.topMargin: 14
      spacing: 10

      Row {
        width: parent.width
        height: 46
        spacing: 10

        StatusChip {
          id: batteryChip
          visible: root.batteryAvailable
          anchors.verticalCenter: parent.verticalCenter
          text: root.batterySummary()
        }

        Item {
          width: Math.max(0, parent.width - (batteryChip.visible ? batteryChip.implicitWidth : 0) - sleepButton.implicitWidth - lockButton.implicitWidth - powerToggleButton.implicitWidth - 30)
          height: parent.height
        }

        CircleIconButton {
          id: sleepButton
          anchors.verticalCenter: parent.verticalCenter
          iconName: "moon"
          onClicked: sessionActions.sleep()
        }

        CircleIconButton {
          id: lockButton
          anchors.verticalCenter: parent.verticalCenter
          iconName: "lock"
          onClicked: sessionActions.lock()
        }

        CircleIconButton {
          id: powerToggleButton
          anchors.verticalCenter: parent.verticalCenter
          iconName: "power"
          active: root.expandedSection === "power"
          onClicked: root.toggleSection("power")
        }
      }

      UiSurface {
        id: powerPopover

        visible: root.expandedSection === "power"
        width: parent.width
        implicitHeight: powerColumn.implicitHeight + 20
        tone: "submenu"
        outlined: false
        radius: 18
        border.width: 1
        border.color: Theme.divider

        Column {
          id: powerColumn

          width: parent.width - 20
          anchors.left: parent.left
          anchors.leftMargin: 10
          anchors.top: parent.top
          anchors.topMargin: 10
          spacing: 8

          UiText {
            text: "Power"
            size: "sm"
            font.weight: Font.DemiBold
          }

          MenuList {
            width: parent.width

            MenuRow {
              width: parent.width
              iconName: "lock"
              title: "Lock"
              compact: true
              dividerVisible: true
              onClicked: sessionActions.lock()
            }

            MenuRow {
              width: parent.width
              iconName: "moon"
              title: "Suspend"
              compact: true
              dividerVisible: true
              onClicked: sessionActions.sleep()
            }

            MenuRow {
              width: parent.width
              iconName: "restart"
              title: root.powerActionLabel("restart", "Restart")
              compact: true
              dividerVisible: true
              active: root.pendingPowerAction === "restart"
              onClicked: root.triggerPowerAction("restart")
            }

            MenuRow {
              width: parent.width
              iconName: "power"
              title: root.powerActionLabel("shutdown", "Power Off")
              compact: true
              dividerVisible: true
              active: root.pendingPowerAction === "shutdown"
              onClicked: root.triggerPowerAction("shutdown")
            }

            MenuRow {
              width: parent.width
              iconName: "logout"
              title: root.powerActionLabel("logout", "Log Out")
              compact: true
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

      Row {
        width: parent.width
        height: 44
        spacing: 10

        IconButton {
          id: muteButton
          anchors.verticalCenter: parent.verticalCenter
          width: implicitWidth
          iconName: root.audioReady && audioService.muted ? "speaker-muted" : "speaker"
          active: root.audioReady && audioService.muted
          enabled: root.audioReady
          onClicked: {
            if (root.audioReady) audioService.toggleMuted();
          }
        }

        MediaSlider {
          width: parent.width - muteButton.width - outputButton.width - parent.spacing * 2
          anchors.verticalCenter: parent.verticalCenter
          showIcon: false
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

        IconButton {
          id: outputButton
          anchors.verticalCenter: parent.verticalCenter
          width: implicitWidth
          iconName: root.expandedSection === "outputs" ? "chevron-down" : "chevron-right"
          active: root.expandedSection === "outputs"
          enabled: Pipewire.ready
          onClicked: root.toggleSection("outputs")
        }
      }

      UiSurface {
        visible: root.expandedSection === "outputs"
        width: parent.width
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

          MenuList {
            width: parent.width

            Repeater {
              model: Pipewire.nodes

              delegate: MenuRow {
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

      Row {
        width: parent.width
        height: 44
        spacing: 10

        IconBadge {
          id: brightnessBadge
          anchors.verticalCenter: parent.verticalCenter
          iconName: "sun"
        }

        MediaSlider {
          id: brightnessSlider

          width: parent.width - brightnessBadge.width - parent.spacing
          anchors.verticalCenter: parent.verticalCenter
          showIcon: false
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

      Column {
        width: parent.width
        spacing: 8

        Row {
          width: parent.width
          spacing: 8

          QuickTile {
            id: wifiTile
            width: Math.floor((parent.width - parent.spacing) / 2)
            iconName: "wifi"
            title: root.wifiTileTitle()
            subtitle: root.wifiTileSubtitle()
            active: wifiService.enabled
            expanded: root.expandedSection === "wifi"
            highlightExpanded: true
            onPrimaryClicked: root.toggleWifiEnabled()
            onSecondaryClicked: root.toggleSection("wifi")
          }

          QuickTile {
            id: bluetoothTile
            width: Math.floor((parent.width - parent.spacing) / 2)
            iconName: "bluetooth"
            title: root.bluetoothTileTitle()
            subtitle: root.bluetoothTileSubtitle()
            active: !!(root.bluetoothAdapter && root.bluetoothAdapter.enabled)
            expanded: root.expandedSection === "bluetooth"
            highlightExpanded: true
            onPrimaryClicked: root.toggleBluetoothEnabled()
            onSecondaryClicked: root.toggleSection("bluetooth")
          }
        }

        UiSurface {
          visible: root.expandedSection === "wifi"
          width: parent.width
          implicitHeight: wifiColumn.implicitHeight + 20
          tone: "submenu"
          outlined: false
          radius: 18
          border.width: 1
          border.color: Theme.divider

          Column {
            id: wifiColumn

            width: parent.width - 20
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.top: parent.top
            anchors.topMargin: 10
            spacing: 8

            UiText {
              text: "Wi-Fi"
              size: "sm"
              font.weight: Font.DemiBold
            }

            UiText {
              visible: !wifiService.hardwareEnabled
              text: "WiFi hardware is blocked."
              size: "xs"
              tone: "accent"
            }

            MenuList {
              width: parent.width
              visible: wifiService.enabled && wifiService.networks.length > 0

              Repeater {
                model: wifiService.enabled ? Math.min(6, wifiService.networks.length) : 0

                delegate: MenuRow {
                  id: wifiRow

                  required property int index
                  readonly property var network: wifiService.networks[index]

                  width: parent.width
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
                  dividerVisible: index < Math.min(6, wifiService.networks.length) - 1
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

                  FlatButton {
                    text: "Connect"
                    active: true
                    enabled: root.wifiPassword !== "" && !wifiService.busy
                    onClicked: root.submitWifiPassword()
                  }

                  FlatButton {
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
              visible: wifiService.enabled && wifiService.networks.length === 0 && !wifiService.busy
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

              FlatButton {
                text: wifiService.enabled ? "Turn Off" : "Turn On"
                onClicked: wifiService.setEnabledState(!wifiService.enabled)
              }

              FlatButton {
                text: wifiService.busy ? "Refreshing" : "Rescan"
                enabled: wifiService.enabled && !wifiService.busy
                onClicked: wifiService.scan()
              }
            }
          }
        }

        UiSurface {
          visible: root.expandedSection === "bluetooth"
          width: parent.width
          implicitHeight: bluetoothColumn.implicitHeight + 20
          tone: "submenu"
          outlined: false
          radius: 18
          border.width: 1
          border.color: Theme.divider

          Column {
            id: bluetoothColumn

            width: parent.width - 20
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.top: parent.top
            anchors.topMargin: 10
            spacing: 8

            UiText {
              text: "Bluetooth"
              size: "sm"
              font.weight: Font.DemiBold
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

            MenuList {
              width: parent.width
              visible: root.bluetoothAdapter && root.bluetoothAdapter.enabled && root.bluetoothConnectedCount() > 0

              Repeater {
                model: root.bluetoothAdapter && root.bluetoothAdapter.enabled ? root.bluetoothAdapter.devices : null

                delegate: MenuRow {
                  id: connectedDeviceRow

                  required property int index
                  required property var modelData
                  readonly property var device: modelData
                  readonly property bool hasNextVisible: {
                    if (!root.bluetoothAdapter || !root.bluetoothAdapter.devices) return false;
                    for (let i = index + 1; i < root.bluetoothAdapter.devices.count; i += 1) {
                      const nextDevice = root.bluetoothAdapter.devices.get(i);
                      if (nextDevice && nextDevice.connected) return true;
                    }
                    return false;
                  }

                  visible: device && device.connected
                  width: parent.width
                  implicitHeight: visible ? 52 : 0
                  height: visible ? implicitHeight : 0
                  iconName: "bluetooth"
                  title: connectedDeviceRow.device.deviceName || connectedDeviceRow.device.name || connectedDeviceRow.device.address
                  subtitle: connectedDeviceRow.device.batteryAvailable
                    ? `${Math.round(connectedDeviceRow.device.battery)}% battery`
                    : "Connected"
                  actionText: connectedDeviceRow.device.state === BluetoothDeviceState.Connecting ? "Working" : "Disconnect"
                  active: true
                  dividerVisible: visible && hasNextVisible
                  onClicked: connectedDeviceRow.device.disconnect()
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

            MenuList {
              width: parent.width
              visible: root.bluetoothAdapter && root.bluetoothAdapter.enabled && root.bluetoothAvailableCount() > 0

              Repeater {
                model: root.bluetoothAdapter && root.bluetoothAdapter.enabled ? root.bluetoothAdapter.devices : null

                delegate: MenuRow {
                  id: otherDeviceRow

                  required property int index
                  required property var modelData
                  readonly property var device: modelData
                  readonly property bool hasNextVisible: {
                    if (!root.bluetoothAdapter || !root.bluetoothAdapter.devices) return false;
                    for (let i = index + 1; i < root.bluetoothAdapter.devices.count; i += 1) {
                      const nextDevice = root.bluetoothAdapter.devices.get(i);
                      if (nextDevice && !nextDevice.connected) return true;
                    }
                    return false;
                  }

                  visible: device && !device.connected
                  width: parent.width
                  implicitHeight: visible ? 52 : 0
                  height: visible ? implicitHeight : 0
                  iconName: "bluetooth"
                  title: otherDeviceRow.device.deviceName || otherDeviceRow.device.name || otherDeviceRow.device.address
                  subtitle: otherDeviceRow.device.paired || otherDeviceRow.device.bonded ? "Paired" : "Available"
                  actionText: otherDeviceRow.device.pairing || otherDeviceRow.device.state === BluetoothDeviceState.Connecting
                    ? "Working"
                    : (otherDeviceRow.device.paired || otherDeviceRow.device.bonded ? "Connect" : "Pair")
                  dividerVisible: visible && hasNextVisible
                  onClicked: {
                    if (otherDeviceRow.device.paired || otherDeviceRow.device.bonded) otherDeviceRow.device.connect();
                    else otherDeviceRow.device.pair();
                  }
                }
              }
            }

            Row {
              width: parent.width
              spacing: 8

              FlatButton {
                text: root.bluetoothAdapter && root.bluetoothAdapter.enabled ? "Turn Off" : "Turn On"
                enabled: !!root.bluetoothAdapter && root.bluetoothAdapter.state !== BluetoothAdapterState.Blocked
                onClicked: root.toggleBluetoothEnabled()
              }

              FlatButton {
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
          width: parent.width
          height: profileRow.height

          Row {
            id: profileRow

            width: parent.width
            spacing: 8

            QuickTile {
              id: profileTile
              width: brightnessService.keyboardAvailable ? Math.floor((parent.width - parent.spacing) / 2) : parent.width
              iconName: "gauge"
              title: root.profileShortLabel()
              subtitle: "Power Mode"
              active: false
              expanded: root.expandedSection === "profile"
              highlightExpanded: true
              onPrimaryClicked: root.cyclePowerProfile()
              onSecondaryClicked: root.toggleSection("profile")
            }

            QuickTile {
              id: keyboardTile
              visible: brightnessService.keyboardAvailable
              width: Math.floor((parent.width - parent.spacing) / 2)
              iconName: "keyboard"
              title: root.keyboardTileTitle()
              subtitle: root.keyboardTileSubtitle()
              active: brightnessService.keyboardAvailable && root.keyboardLevelIndex() > 0
              expanded: root.expandedSection === "keyboard"
              highlightExpanded: true
              onPrimaryClicked: root.cycleKeyboardBacklight()
              onSecondaryClicked: root.toggleSection("keyboard")
            }
          }

          PopoverSurface {
            id: profilePopover
            visible: root.expandedSection === "profile"
            width: Math.max(profileTile.width, 188)
            x: root.clamp(profileTile.x + (profileTile.width - width) / 2, 0, profileRow.width - width)
            y: (profileTile.height - implicitHeight) / 2
            z: 2

            MenuList {
              width: parent.width

              MenuRow {
                width: parent.width
                iconName: "gauge"
                title: "Performance"
                trailingIconName: PowerProfiles.profile === PowerProfile.Performance ? "check" : ""
                active: PowerProfiles.profile === PowerProfile.Performance
                compact: true
                dividerVisible: true
                enabled: PowerProfiles.hasPerformanceProfile
                onClicked: root.selectPowerProfile(PowerProfile.Performance)
              }

              MenuRow {
                width: parent.width
                iconName: "gauge"
                title: "Balanced"
                trailingIconName: PowerProfiles.profile === PowerProfile.Balanced ? "check" : ""
                active: PowerProfiles.profile === PowerProfile.Balanced
                compact: true
                dividerVisible: true
                onClicked: root.selectPowerProfile(PowerProfile.Balanced)
              }

              MenuRow {
                width: parent.width
                iconName: "gauge"
                title: "Power Saver"
                trailingIconName: PowerProfiles.profile === PowerProfile.PowerSaver ? "check" : ""
                active: PowerProfiles.profile === PowerProfile.PowerSaver
                compact: true
                onClicked: root.selectPowerProfile(PowerProfile.PowerSaver)
              }
            }
          }
        }
      }

      UiText {
        visible: audioService.lastError !== ""
        text: audioService.lastError
        size: "xs"
        tone: "accent"
        wrapMode: Text.WordWrap
      }

      UiText {
        visible: brightnessService.lastError !== ""
        text: brightnessService.lastError
        size: "xs"
        tone: "accent"
        wrapMode: Text.WordWrap
      }
    }

    Item {
      id: popoverLayer

      anchors.fill: parent
      z: 6

      PopoverSurface {
        visible: root.expandedSection === "keyboard" && brightnessService.keyboardAvailable
        width: keyboardTile.width
        x: root.popupX(keyboardTile, width, true)
        y: root.popupY(keyboardTile, 8)

        MenuList {
          width: parent.width

          MenuRow {
            width: parent.width
            iconName: "keyboard"
            title: "Off"
            trailingIconName: root.keyboardLevelIndex() === 0 ? "check" : ""
            active: root.keyboardLevelIndex() === 0
            compact: true
            dividerVisible: true
            onClicked: root.setKeyboardLevel(0)
          }

          MenuRow {
            width: parent.width
            iconName: "keyboard"
            title: "Low"
            trailingIconName: root.keyboardLevelIndex() === 1 ? "check" : ""
            active: root.keyboardLevelIndex() === 1
            compact: true
            dividerVisible: true
            onClicked: root.setKeyboardLevel(1)
          }

          MenuRow {
            width: parent.width
            iconName: "keyboard"
            title: "Med"
            trailingIconName: root.keyboardLevelIndex() === 2 ? "check" : ""
            active: root.keyboardLevelIndex() === 2
            compact: true
            dividerVisible: true
            onClicked: root.setKeyboardLevel(2)
          }

          MenuRow {
            width: parent.width
            iconName: "keyboard"
            title: "High"
            trailingIconName: root.keyboardLevelIndex() === 3 ? "check" : ""
            active: root.keyboardLevelIndex() === 3
            compact: true
            onClicked: root.setKeyboardLevel(3)
          }
        }
      }

    }
  }
}
