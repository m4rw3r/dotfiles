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
  readonly property var audioSink: Pipewire.defaultAudioSink
  readonly property var audioNode: audioSink && audioSink.audio ? audioSink.audio : null
  readonly property var battery: UPower.displayDevice
  readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
  readonly property bool batteryAvailable: battery && battery.isPresent && battery.isLaptopBattery
  readonly property bool audioReady: audioService.ready

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

    const percent = `${Math.round(battery.percentage || 0)}%`;
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

  onVisibleChanged: {
    if (visible) {
      forceActiveFocus();
      audioService.refresh();
      brightnessService.refresh();
      wifiService.refresh();
      pendingAudioVolume = audioService.volume;
      pendingScreenBrightness = brightnessService.screenPercent;
    } else {
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

  component FlatButton: UiSurface {
    id: button

    property string text: ""
    property bool active: false
    property string toneName: active ? "toggleOn" : "fieldAlt"
    property bool compact: false
    signal clicked()

    width: implicitWidth
    implicitWidth: Math.max(compact ? 82 : 102, buttonLabel.implicitWidth + 28)
    implicitHeight: compact ? 34 : 40
    tone: toneName
    outlined: false
    radius: 18
    pressed: buttonTouch.pressed
    opacity: enabled ? 1 : 0.45

    border.width: 1
    border.color: active ? Qt.rgba(1, 1, 1, 0.08) : Theme.divider

    UiText {
      id: buttonLabel

      anchors.centerIn: parent
      text: button.text
      size: "sm"
      tone: button.active ? "onAccent" : "primary"
      font.weight: Font.DemiBold
    }

    MouseArea {
      id: buttonTouch

      anchors.fill: parent
      enabled: button.enabled
      onClicked: button.clicked()
    }
  }

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

  component GlyphIcon: Canvas {
    id: glyph

    property string name: "chevron-right"
    property color strokeColor: Theme.textMuted
    property real stroke: 1.75

    implicitWidth: 20
    implicitHeight: 20
    contextType: "2d"
    renderStrategy: Canvas.Cooperative

    onNameChanged: requestPaint()
    onStrokeColorChanged: requestPaint()
    onStrokeChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
      const ctx = getContext("2d");
      ctx.reset();
      ctx.strokeStyle = strokeColor;
      ctx.lineWidth = stroke;
      ctx.lineCap = "round";
      ctx.lineJoin = "round";

      const w = width;
      const h = height;

      function roundedRect(x, y, rectWidth, rectHeight, radius) {
        ctx.beginPath();
        ctx.moveTo(x + radius, y);
        ctx.lineTo(x + rectWidth - radius, y);
        ctx.arcTo(x + rectWidth, y, x + rectWidth, y + radius, radius);
        ctx.lineTo(x + rectWidth, y + rectHeight - radius);
        ctx.arcTo(x + rectWidth, y + rectHeight, x + rectWidth - radius, y + rectHeight, radius);
        ctx.lineTo(x + radius, y + rectHeight);
        ctx.arcTo(x, y + rectHeight, x, y + rectHeight - radius, radius);
        ctx.lineTo(x, y + radius);
        ctx.arcTo(x, y, x + radius, y, radius);
      }

      if (name === "chevron-right") {
        ctx.beginPath();
        ctx.moveTo(w * 0.36, h * 0.24);
        ctx.lineTo(w * 0.66, h * 0.5);
        ctx.lineTo(w * 0.36, h * 0.76);
        ctx.stroke();
        return;
      }

      if (name === "chevron-down") {
        ctx.beginPath();
        ctx.moveTo(w * 0.26, h * 0.38);
        ctx.lineTo(w * 0.5, h * 0.68);
        ctx.lineTo(w * 0.74, h * 0.38);
        ctx.stroke();
        return;
      }

      if (name === "check") {
        ctx.beginPath();
        ctx.moveTo(w * 0.22, h * 0.54);
        ctx.lineTo(w * 0.42, h * 0.72);
        ctx.lineTo(w * 0.78, h * 0.28);
        ctx.stroke();
        return;
      }

      if (name === "restart") {
        ctx.beginPath();
        ctx.arc(w * 0.5, h * 0.54, h * 0.23, Math.PI * 0.12, Math.PI * 1.64, true);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(w * 0.35, h * 0.18);
        ctx.lineTo(w * 0.58, h * 0.18);
        ctx.lineTo(w * 0.48, h * 0.34);
        ctx.stroke();
        return;
      }

      if (name === "logout") {
        roundedRect(w * 0.18, h * 0.24, w * 0.34, h * 0.52, h * 0.08);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(w * 0.42, h * 0.5);
        ctx.lineTo(w * 0.8, h * 0.5);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(w * 0.62, h * 0.32);
        ctx.lineTo(w * 0.8, h * 0.5);
        ctx.lineTo(w * 0.62, h * 0.68);
        ctx.stroke();
        return;
      }

      if (name === "sun") {
        ctx.beginPath();
        ctx.arc(w * 0.5, h * 0.5, h * 0.17, 0, Math.PI * 2, false);
        ctx.stroke();
        for (let i = 0; i < 8; i += 1) {
          const angle = (Math.PI * 2 * i) / 8;
          const inner = h * 0.3;
          const outer = h * 0.42;
          ctx.beginPath();
          ctx.moveTo(w * 0.5 + Math.cos(angle) * inner, h * 0.5 + Math.sin(angle) * inner);
          ctx.lineTo(w * 0.5 + Math.cos(angle) * outer, h * 0.5 + Math.sin(angle) * outer);
          ctx.stroke();
        }
        return;
      }

      if (name === "lock") {
        roundedRect(w * 0.26, h * 0.44, w * 0.48, h * 0.32, h * 0.06);
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(w * 0.5, h * 0.42, h * 0.14, Math.PI, 0, false);
        ctx.stroke();
        return;
      }

      if (name === "power") {
        ctx.beginPath();
        ctx.arc(w * 0.5, h * 0.55, h * 0.22, Math.PI * 0.8, Math.PI * 2.2, false);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(w * 0.5, h * 0.16);
        ctx.lineTo(w * 0.5, h * 0.42);
        ctx.stroke();
        return;
      }

      if (name === "moon") {
        ctx.beginPath();
        ctx.arc(w * 0.46, h * 0.5, h * 0.2, Math.PI * 0.28, Math.PI * 1.72, false);
        ctx.arc(w * 0.56, h * 0.45, h * 0.18, Math.PI * 1.15, Math.PI * 0.82, true);
        ctx.stroke();
        return;
      }

      if (name === "wifi") {
        ctx.beginPath();
        ctx.arc(w * 0.5, h * 0.68, h * 0.03, 0, Math.PI * 2, false);
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(w * 0.5, h * 0.6, h * 0.12, Math.PI * 1.18, Math.PI * 1.82, false);
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(w * 0.5, h * 0.6, h * 0.22, Math.PI * 1.18, Math.PI * 1.82, false);
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(w * 0.5, h * 0.6, h * 0.32, Math.PI * 1.18, Math.PI * 1.82, false);
        ctx.stroke();
        return;
      }

      if (name === "bluetooth") {
        ctx.beginPath();
        ctx.moveTo(w * 0.5, h * 0.16);
        ctx.lineTo(w * 0.5, h * 0.84);
        ctx.moveTo(w * 0.5, h * 0.16);
        ctx.lineTo(w * 0.69, h * 0.34);
        ctx.lineTo(w * 0.5, h * 0.5);
        ctx.lineTo(w * 0.69, h * 0.66);
        ctx.lineTo(w * 0.5, h * 0.84);
        ctx.moveTo(w * 0.5, h * 0.5);
        ctx.lineTo(w * 0.29, h * 0.3);
        ctx.moveTo(w * 0.5, h * 0.5);
        ctx.lineTo(w * 0.29, h * 0.7);
        ctx.stroke();
        return;
      }

      if (name === "gauge") {
        ctx.beginPath();
        ctx.arc(w * 0.5, h * 0.62, h * 0.22, Math.PI, Math.PI * 2, false);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(w * 0.5, h * 0.62);
        ctx.lineTo(w * 0.67, h * 0.45);
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(w * 0.5, h * 0.62, h * 0.03, 0, Math.PI * 2, false);
        ctx.stroke();
        return;
      }

      if (name === "keyboard") {
        roundedRect(w * 0.18, h * 0.34, w * 0.64, h * 0.32, h * 0.05);
        ctx.stroke();
        for (let row = 0; row < 2; row += 1) {
          for (let col = 0; col < 5; col += 1) {
            ctx.beginPath();
            ctx.arc(w * (0.28 + col * 0.1), h * (0.44 + row * 0.1), 0.6, 0, Math.PI * 2, false);
            ctx.stroke();
          }
        }
        ctx.beginPath();
        ctx.moveTo(w * 0.34, h * 0.6);
        ctx.lineTo(w * 0.66, h * 0.6);
        ctx.stroke();
        return;
      }

      ctx.beginPath();
      ctx.moveTo(w * 0.18, h * 0.42);
      ctx.lineTo(w * 0.34, h * 0.42);
      ctx.lineTo(w * 0.48, h * 0.3);
      ctx.lineTo(w * 0.48, h * 0.7);
      ctx.lineTo(w * 0.34, h * 0.58);
      ctx.lineTo(w * 0.18, h * 0.58);
      ctx.closePath();
      ctx.stroke();

      if (name === "speaker") {
        ctx.beginPath();
        ctx.arc(w * 0.48, h * 0.5, h * 0.13, -0.9, 0.9, false);
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(w * 0.48, h * 0.5, h * 0.24, -0.9, 0.9, false);
        ctx.stroke();
        return;
      }

      if (name === "speaker-muted") {
        ctx.beginPath();
        ctx.moveTo(w * 0.58, h * 0.34);
        ctx.lineTo(w * 0.8, h * 0.66);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(w * 0.8, h * 0.34);
        ctx.lineTo(w * 0.58, h * 0.66);
        ctx.stroke();
      }
    }
  }

  component IconButton: UiSurface {
    id: iconButton

    property string iconName: "chevron-right"
    property bool active: false
    signal clicked()

    width: implicitWidth
    implicitWidth: 44
    implicitHeight: 44
    tone: active ? "toggleOn" : "fieldAlt"
    outlined: false
    radius: 19
    pressed: iconTouch.pressed
    opacity: enabled ? 1 : 0.45

    border.width: 1
    border.color: active ? Qt.rgba(1, 1, 1, 0.08) : Theme.divider

    GlyphIcon {
      anchors.centerIn: parent
      name: iconButton.iconName
      strokeColor: iconButton.active ? Theme.textOnAccent : Theme.iconSecondary
    }

    MouseArea {
      id: iconTouch

      anchors.fill: parent
      enabled: iconButton.enabled
      onClicked: iconButton.clicked()
    }
  }

  component ExpandButton: UiSurface {
    id: expandButton

    property string title: ""
    property string summary: ""
    property bool expanded: false
    signal clicked()

    implicitWidth: parent ? parent.width : 0
    implicitHeight: 44
    tone: expanded ? "submenu" : "fieldAlt"
    outlined: false
    radius: 19
    pressed: expandTouch.pressed

    border.width: 1
    border.color: Theme.divider

    Row {
      anchors.fill: parent
       anchors.leftMargin: 14
       anchors.rightMargin: 14
       spacing: 10

      UiText {
        id: expandTitle

        anchors.verticalCenter: parent.verticalCenter
        text: expandButton.title
         size: "sm"
         font.weight: Font.DemiBold
      }

      Item {
        width: Math.max(0, parent.width - expandTitle.implicitWidth - expandSummary.implicitWidth - expandChevron.implicitWidth - 16)
        height: parent.height
      }

      UiText {
        id: expandSummary

        width: Math.max(0, parent.width - expandTitle.implicitWidth - expandChevron.implicitWidth - 24)
        anchors.verticalCenter: parent.verticalCenter
        text: expandButton.summary
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        size: "xs"
        tone: "muted"
      }

      GlyphIcon {
        id: expandChevron

        anchors.verticalCenter: parent.verticalCenter
        name: expandButton.expanded ? "chevron-down" : "chevron-right"
         strokeColor: Theme.iconSecondary
      }
    }

    MouseArea {
      id: expandTouch

      anchors.fill: parent
      onClicked: expandButton.clicked()
    }
  }

  component CircleIconButton: UiSurface {
    id: circleButton

    property string iconName: "power"
    property bool active: false
    signal clicked()

    implicitWidth: 46
    implicitHeight: 46
    radius: width / 2
    tone: active ? "toggleOn" : "fieldAlt"
    outlined: false
    pressed: circleTouch.pressed

    border.width: 1
    border.color: active ? Qt.rgba(1, 1, 1, 0.08) : Theme.divider

    GlyphIcon {
      anchors.centerIn: parent
      name: circleButton.iconName
      strokeColor: circleButton.active ? Theme.textOnAccent : Theme.iconSecondary
    }

    MouseArea {
      id: circleTouch

      anchors.fill: parent
      onClicked: circleButton.clicked()
    }
  }

  component IconBadge: UiSurface {
    id: badge

    property string iconName: "sun"

    implicitWidth: 44
    implicitHeight: 44
    tone: "fieldAlt"
    outlined: false
    radius: 19
    border.width: 1
    border.color: Theme.divider

    GlyphIcon {
      anchors.centerIn: parent
      name: badge.iconName
      strokeColor: Theme.iconSecondary
    }
  }

  component QuickTile: Item {
    id: tile

    property string iconName: "wifi"
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool expanded: false
    property bool expandable: true
    property bool highlightExpanded: false
    signal primaryClicked()
    signal secondaryClicked()

    implicitWidth: parent ? Math.floor((parent.width - 10) / 2) : 180
    implicitHeight: 44

    readonly property bool highlighted: active || (highlightExpanded && expanded)
    readonly property real splitWidth: tile.expandable ? 52 : 0
    readonly property bool pressed: primaryTouch.pressed || (tile.expandable && secondaryTouch.pressed)
    readonly property color tileColor: highlighted
      ? (pressed ? Theme.toggleOnStrong : Theme.toggleOn)
      : (pressed ? Theme.fieldPressed : Theme.toggleOff)
    readonly property color splitColor: highlighted
      ? Theme.toggleOnStrong
      : Theme.fieldAlt

    Rectangle {
      anchors.fill: parent
      radius: 19
      color: tile.tileColor
      border.width: 1
      border.color: tile.highlighted ? Qt.rgba(1, 1, 1, 0.08) : Theme.divider
    }

    Rectangle {
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      width: tile.expandable ? 52 : 0
      radius: 19
      color: tile.splitColor
      visible: tile.expandable
    }

    Rectangle {
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      anchors.rightMargin: tile.splitWidth
      width: 1
      color: tile.active ? Qt.rgba(1, 1, 1, 0.14) : Theme.divider
      visible: tile.expandable
    }

    Row {
      anchors.fill: parent
      anchors.leftMargin: 16
      anchors.rightMargin: 12
      spacing: 10

      GlyphIcon {
        anchors.verticalCenter: parent.verticalCenter
        name: tile.iconName
        strokeColor: tile.highlighted ? Theme.textOnAccent : Theme.textMuted
      }

      Item {
        width: Math.max(0, parent.width - (tile.expandable ? 78 : 34))
        height: parent.height

        UiText {
          anchors.verticalCenter: parent.verticalCenter
          text: tile.title
          size: "sm"
          tone: tile.highlighted ? "onAccent" : "primary"
          font.weight: Font.DemiBold
          elide: Text.ElideRight
        }
      }

      Item {
        visible: tile.expandable
        width: 40
        height: parent.height

        GlyphIcon {
          anchors.centerIn: parent
          visible: tile.expandable
          name: tile.expanded ? "chevron-down" : "chevron-right"
          strokeColor: tile.highlighted ? Theme.textOnAccent : Theme.iconSecondary
        }
      }
    }

    MouseArea {
      id: primaryTouch

      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      anchors.rightMargin: tile.splitWidth
      onClicked: tile.primaryClicked()
    }

    MouseArea {
      id: secondaryTouch

      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      width: tile.expandable ? 52 : 0
      enabled: tile.expandable
      onClicked: tile.secondaryClicked()
    }
  }

  component MediaSlider: Item {
    id: mediaSlider

    property string iconName: "speaker"
    property bool showIcon: true
    property real from: 0
    property real to: 1
    property real value: 0
    property real dragValue: value
    property string valueText: ""
    property bool showValueText: false
    signal valueMoved(real value)
    signal valueCommitted(real value)

    implicitWidth: parent ? parent.width : 0
    implicitHeight: 46

    onValueChanged: {
      if (!mediaControl.pressed) dragValue = value;
    }

    Row {
      anchors.fill: parent
      spacing: 12

      GlyphIcon {
        id: startIcon

        anchors.verticalCenter: parent.verticalCenter
        visible: mediaSlider.showIcon
        name: mediaSlider.iconName
        strokeColor: mediaSlider.enabled ? Theme.text : Theme.textSubtle
      }

      Item {
         width: parent.width - (mediaSlider.showIcon ? startIcon.width : 0) - detailSlot.width - parent.spacing * (mediaSlider.showIcon ? 2 : 1)
         height: parent.height

        Slider {
          id: mediaControl

          anchors.fill: parent
          from: mediaSlider.from
          to: mediaSlider.to
          value: mediaSlider.dragValue
          enabled: mediaSlider.enabled

          onValueChanged: {
            if (!pressed) return;
            mediaSlider.dragValue = value;
            mediaSlider.valueMoved(value);
          }
          onPressedChanged: {
            if (!pressed) mediaSlider.valueCommitted(mediaSlider.dragValue);
          }

          background: Rectangle {
            x: mediaControl.leftPadding
            y: mediaControl.topPadding + mediaControl.availableHeight / 2 - height / 2
            width: mediaControl.availableWidth
             height: 6
             radius: 3
             color: Theme.sliderTrack

             Rectangle {
               width: Math.max(parent.height, mediaControl.visualPosition * parent.width)
               height: parent.height
               radius: parent.radius
               color: Theme.sliderFill
             }
           }

           handle: Rectangle {
             x: mediaControl.leftPadding + mediaControl.visualPosition * (mediaControl.availableWidth - width)
             y: mediaControl.topPadding + mediaControl.availableHeight / 2 - height / 2
             width: 18
             height: 18
             radius: 9
             color: Theme.text
             border.width: 1
             border.color: Theme.panelRaised
           }
         }
      }

      Item {
        id: detailSlot

        width: mediaSlider.showValueText ? valueLabel.implicitWidth : 0
        height: parent.height

        UiText {
          id: valueLabel

          anchors.verticalCenter: parent.verticalCenter
          text: mediaSlider.valueText
          visible: mediaSlider.showValueText
          size: "xs"
          tone: "muted"
          font.weight: Font.DemiBold
        }
      }
    }
  }

  component InlineSlider: Item {
    id: inlineSlider

    property string title: ""
    property string valueText: ""
    property real from: 0
    property real to: 100
    property real stepSize: 0
    property real value: 0
    property real dragValue: value
    signal valueMoved(real value)
    signal valueCommitted(real value)

    implicitWidth: parent ? parent.width : 0
    implicitHeight: 46

    onValueChanged: {
      if (!slider.pressed) dragValue = value;
    }

    UiSurface {
      anchors.fill: parent
      tone: "submenu"
      outlined: false
      radius: 18
      opacity: inlineSlider.enabled ? 1 : 0.45
      clip: true

      border.width: 1
      border.color: Theme.divider

      Slider {
        id: slider

        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
         anchors.topMargin: 6
         anchors.bottomMargin: 6
        from: inlineSlider.from
        to: inlineSlider.to
        stepSize: inlineSlider.stepSize
        value: inlineSlider.dragValue
        enabled: inlineSlider.enabled
        leftPadding: titleLabel.implicitWidth + 28
        rightPadding: valueLabel.implicitWidth + 28

        onValueChanged: {
          if (!pressed) return;
          inlineSlider.dragValue = value;
          inlineSlider.valueMoved(value);
        }
        onPressedChanged: {
          if (!pressed) inlineSlider.valueCommitted(inlineSlider.dragValue);
        }

        background: Rectangle {
          x: slider.leftPadding
          y: slider.topPadding + slider.availableHeight / 2 - height / 2
          width: slider.availableWidth
           height: 6
           radius: 3
           color: Theme.sliderTrack

           Rectangle {
             width: Math.max(parent.height, slider.visualPosition * parent.width)
             height: parent.height
             radius: parent.radius
             color: Theme.sliderFill
             opacity: inlineSlider.enabled ? 0.95 : 0.45
           }
         }

         handle: Rectangle {
           x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
           y: slider.topPadding + slider.availableHeight / 2 - height / 2
           width: 18
           height: 18
           radius: 9
           color: slider.enabled ? Theme.text : Theme.textSubtle
           border.width: 1
           border.color: Theme.panelRaised
        }
      }

      UiText {
        id: titleLabel

        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: inlineSlider.title
        size: "sm"
        tone: inlineSlider.enabled ? "primary" : "subtle"
        font.weight: Font.DemiBold
      }

      UiText {
        id: valueLabel

        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: inlineSlider.valueText
        size: "xs"
        tone: inlineSlider.enabled ? "muted" : "subtle"
        font.weight: Font.DemiBold
      }
    }
  }

  component ActionButton: UiSurface {
    id: actionButton

    property string title: ""
    property bool active: false
    signal clicked()

    width: implicitWidth
    implicitWidth: 1
    implicitHeight: 44
    tone: active ? "toggleOn" : "toggleOff"
    outlined: false
    radius: 18
    pressed: actionTouch.pressed
    opacity: enabled ? 1 : 0.45

    border.width: 1
    border.color: active ? Qt.rgba(1, 1, 1, 0.08) : Theme.divider

    UiText {
      anchors.centerIn: parent
      text: actionButton.title
      size: "sm"
      tone: actionButton.active ? "onAccent" : "primary"
      font.weight: Font.DemiBold
    }

    MouseArea {
      id: actionTouch

      anchors.fill: parent
      enabled: actionButton.enabled
      onClicked: actionButton.clicked()
    }
  }

  component MenuList: UiSurface {
    id: menuList

    default property alias content: listColumn.data

    width: parent ? parent.width : implicitWidth
    implicitWidth: 1
    implicitHeight: listColumn.implicitHeight + 12
    tone: "panelOverlay"
    outlined: false
    radius: 16

    border.width: 1
    border.color: Theme.border

    Column {
      id: listColumn

      width: parent.width - 20
      anchors.left: parent.left
      anchors.leftMargin: 10
      anchors.top: parent.top
      anchors.topMargin: 6
      spacing: 1
    }
  }

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

  component MenuRow: Item {
    id: menuRow

    property string iconName: "wifi"
    property string title: ""
    property string subtitle: ""
    property string actionText: ""
    property string trailingIconName: ""
    property bool active: false
    property bool dividerVisible: false
    property bool compact: false
    signal clicked()

    width: parent ? parent.width : implicitWidth
    implicitWidth: 1
    implicitHeight: compact || subtitle === "" ? 42 : 50
    opacity: enabled ? 1 : 0.45

    Rectangle {
      anchors.fill: parent
      radius: 12
      color: menuRow.active ? Theme.toggleOn : (rowTouch.pressed ? Theme.fieldAlt : "transparent")
      border.width: menuRow.active ? 1 : 0
      border.color: menuRow.active ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
    }

    Row {
      anchors.fill: parent
      anchors.leftMargin: 14
      anchors.rightMargin: 14
      spacing: 14

      GlyphIcon {
        anchors.verticalCenter: parent.verticalCenter
        name: menuRow.iconName
        strokeColor: menuRow.active ? Theme.textOnAccent : Theme.iconSecondary
      }

      Column {
        width: Math.max(0, parent.width - trailingSlot.width - 42)
        anchors.verticalCenter: parent.verticalCenter
        spacing: menuRow.compact ? 0 : 1

        UiText {
          text: menuRow.title
          size: "sm"
          tone: menuRow.active ? "onAccent" : "primary"
          font.weight: Font.DemiBold
          elide: Text.ElideRight
        }

        UiText {
          text: menuRow.subtitle
          visible: !menuRow.compact && text !== ""
          size: "xs"
          tone: menuRow.active ? "onAccent" : "muted"
          opacity: menuRow.active ? 0.9 : 0.96
          elide: Text.ElideRight
        }
      }

      Item {
        id: trailingSlot

        width: actionLabel.visible || trailingGlyph.visible ? Math.max(actionLabel.implicitWidth, trailingGlyph.implicitWidth) : 0
        height: parent.height

        UiText {
          id: actionLabel

          anchors.verticalCenter: parent.verticalCenter
          anchors.right: parent.right
          text: menuRow.actionText
          visible: text !== ""
          size: "xs"
          tone: menuRow.active ? "onAccent" : "muted"
          font.weight: Font.DemiBold
        }

        GlyphIcon {
          id: trailingGlyph

          anchors.verticalCenter: parent.verticalCenter
          anchors.right: parent.right
          name: menuRow.trailingIconName
          visible: name !== ""
          strokeColor: menuRow.active ? Theme.textOnAccent : Theme.iconSecondary
        }
      }
    }

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.leftMargin: 18
      anchors.rightMargin: 18
      height: 1
      color: Theme.divider
      visible: menuRow.dividerVisible && !menuRow.active
    }

    MouseArea {
      id: rowTouch

      anchors.fill: parent
      enabled: menuRow.enabled
      onClicked: menuRow.clicked()
    }
  }

  component BrightnessController: Item {
    id: brightnessController

    property bool ready: false
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

    Column {
      id: content

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
                onClicked: PowerProfiles.profile = PowerProfile.Performance
              }

              MenuRow {
                width: parent.width
                iconName: "gauge"
                title: "Balanced"
                trailingIconName: PowerProfiles.profile === PowerProfile.Balanced ? "check" : ""
                active: PowerProfiles.profile === PowerProfile.Balanced
                compact: true
                dividerVisible: true
                onClicked: PowerProfiles.profile = PowerProfile.Balanced
              }

              MenuRow {
                width: parent.width
                iconName: "gauge"
                title: "Power Saver"
                trailingIconName: PowerProfiles.profile === PowerProfile.PowerSaver ? "check" : ""
                active: PowerProfiles.profile === PowerProfile.PowerSaver
                compact: true
                onClicked: PowerProfiles.profile = PowerProfile.PowerSaver
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
        visible: root.expandedSection === "outputs"
        width: 232
        x: root.popupX(outputButton, width, true)
        y: root.popupY(outputButton, 8)

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
