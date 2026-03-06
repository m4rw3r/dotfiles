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

  implicitWidth: 432
  implicitHeight: panel.implicitHeight

  property string expandedSection: ""
  property string pendingPowerAction: ""
  property string wifiPasswordTarget: ""
  property string wifiPassword: ""
  property real pendingScreenBrightness: 0
  readonly property var audioSink: Pipewire.defaultAudioSink
  readonly property var audioNode: audioSink && audioSink.audio ? audioSink.audio : null
  readonly property var battery: UPower.displayDevice
  readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
  readonly property bool batteryAvailable: battery && battery.isPresent && battery.isLaptopBattery
  readonly property bool audioReady: Pipewire.ready && audioSink !== null && audioNode !== null

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
    return brightnessService.keyboardAvailable ? `${brightnessService.keyboardPercent}%` : "Keyboard";
  }

  function keyboardTileSubtitle() {
    return brightnessService.keyboardAvailable ? "Backlight" : "Unavailable";
  }

  function outputLabel(node) {
    if (!node) return "Unknown output";
    return node.description || node.nickname || node.name || "Unknown output";
  }

  function audioVolumeValue() {
    if (!audioReady) return 0;
    return clamp(Number(audioNode.volume), 0, 1);
  }

  function audioVolumePercentText() {
    if (!audioReady) return "Unavailable";
    if (audioNode.muted) return "Muted";
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

  onVisibleChanged: {
    if (visible) {
      forceActiveFocus();
      brightnessService.refresh();
      wifiService.refresh();
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
    property string toneName: active ? "accent" : "field"
    property bool compact: false
    signal clicked()

    width: implicitWidth
    implicitWidth: Math.max(compact ? 74 : 96, buttonLabel.implicitWidth + 22)
    implicitHeight: compact ? 32 : 38
    tone: toneName
    outlined: !active
    pressed: buttonTouch.pressed
    opacity: enabled ? 1 : 0.45

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

    implicitWidth: chipLabel.implicitWidth + 20
    implicitHeight: chipLabel.implicitHeight + 14
    tone: "field"
    outlined: false
    radius: 16

    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.08)

    UiText {
      id: chipLabel

      anchors.centerIn: parent
      text: chip.text
      size: "xs"
      tone: "muted"
      font.weight: Font.DemiBold
    }
  }

  component GlyphIcon: Canvas {
    id: glyph

    property string name: "chevron-right"
    property color strokeColor: Theme.textMuted
    property real stroke: 1.9

    implicitWidth: 18
    implicitHeight: 18
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

      if (name === "chevron-right") {
        ctx.beginPath();
        ctx.moveTo(w * 0.34, h * 0.24);
        ctx.lineTo(w * 0.68, h * 0.5);
        ctx.lineTo(w * 0.34, h * 0.76);
        ctx.stroke();
        return;
      }

      if (name === "chevron-down") {
        ctx.beginPath();
        ctx.moveTo(w * 0.24, h * 0.36);
        ctx.lineTo(w * 0.5, h * 0.68);
        ctx.lineTo(w * 0.76, h * 0.36);
        ctx.stroke();
        return;
      }

      if (name === "sun") {
        ctx.beginPath();
        ctx.arc(w * 0.5, h * 0.5, h * 0.16, 0, Math.PI * 2, false);
        ctx.stroke();
        for (let i = 0; i < 8; i += 1) {
          const angle = (Math.PI * 2 * i) / 8;
          const inner = h * 0.28;
          const outer = h * 0.4;
          ctx.beginPath();
          ctx.moveTo(w * 0.5 + Math.cos(angle) * inner, h * 0.5 + Math.sin(angle) * inner);
          ctx.lineTo(w * 0.5 + Math.cos(angle) * outer, h * 0.5 + Math.sin(angle) * outer);
          ctx.stroke();
        }
        return;
      }

      if (name === "lock") {
        ctx.beginPath();
        ctx.rect(w * 0.26, h * 0.44, w * 0.48, h * 0.34);
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(w * 0.5, h * 0.42, h * 0.15, Math.PI, 0, false);
        ctx.stroke();
        return;
      }

      if (name === "power") {
        ctx.beginPath();
        ctx.arc(w * 0.5, h * 0.54, h * 0.22, Math.PI * 0.82, Math.PI * 2.18, false);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(w * 0.5, h * 0.18);
        ctx.lineTo(w * 0.5, h * 0.48);
        ctx.stroke();
        return;
      }

      if (name === "moon") {
        ctx.beginPath();
        ctx.arc(w * 0.48, h * 0.5, h * 0.22, Math.PI * 0.28, Math.PI * 1.72, false);
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(w * 0.58, h * 0.46, h * 0.2, Math.PI * 1.2, Math.PI * 0.8, true);
        ctx.stroke();
        return;
      }

      if (name === "wifi") {
        ctx.beginPath();
        ctx.arc(w * 0.5, h * 0.62, h * 0.06, 0, Math.PI * 2, false);
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(w * 0.5, h * 0.58, h * 0.16, Math.PI * 1.16, Math.PI * 1.84, false);
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(w * 0.5, h * 0.58, h * 0.28, Math.PI * 1.16, Math.PI * 1.84, false);
        ctx.stroke();
        return;
      }

      if (name === "bluetooth") {
        ctx.beginPath();
        ctx.moveTo(w * 0.5, h * 0.16);
        ctx.lineTo(w * 0.5, h * 0.84);
        ctx.lineTo(w * 0.72, h * 0.64);
        ctx.moveTo(w * 0.5, h * 0.16);
        ctx.lineTo(w * 0.72, h * 0.36);
        ctx.moveTo(w * 0.5, h * 0.5);
        ctx.lineTo(w * 0.26, h * 0.28);
        ctx.moveTo(w * 0.5, h * 0.5);
        ctx.lineTo(w * 0.26, h * 0.72);
        ctx.stroke();
        return;
      }

      if (name === "gauge") {
        ctx.beginPath();
        ctx.arc(w * 0.5, h * 0.58, h * 0.24, Math.PI, Math.PI * 2, false);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(w * 0.5, h * 0.58);
        ctx.lineTo(w * 0.66, h * 0.42);
        ctx.stroke();
        return;
      }

      if (name === "keyboard") {
        ctx.beginPath();
        ctx.rect(w * 0.18, h * 0.34, w * 0.64, h * 0.32);
        ctx.stroke();
        for (let row = 0; row < 2; row += 1) {
          for (let col = 0; col < 4; col += 1) {
            ctx.beginPath();
            ctx.arc(w * (0.3 + col * 0.12), h * (0.46 + row * 0.1), 1, 0, Math.PI * 2, false);
            ctx.stroke();
          }
        }
        return;
      }

      ctx.beginPath();
      ctx.moveTo(w * 0.16, h * 0.42);
      ctx.lineTo(w * 0.33, h * 0.42);
      ctx.lineTo(w * 0.48, h * 0.28);
      ctx.lineTo(w * 0.48, h * 0.72);
      ctx.lineTo(w * 0.33, h * 0.58);
      ctx.lineTo(w * 0.16, h * 0.58);
      ctx.closePath();
      ctx.stroke();

      if (name === "speaker") {
        ctx.beginPath();
        ctx.arc(w * 0.5, h * 0.5, h * 0.12, -0.85, 0.85, false);
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(w * 0.5, h * 0.5, h * 0.24, -0.85, 0.85, false);
        ctx.stroke();
        return;
      }

      if (name === "speaker-muted") {
        ctx.beginPath();
        ctx.moveTo(w * 0.58, h * 0.34);
        ctx.lineTo(w * 0.82, h * 0.68);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(w * 0.82, h * 0.34);
        ctx.lineTo(w * 0.58, h * 0.68);
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
    implicitWidth: 42
    implicitHeight: 42
    tone: active ? "accent" : "field"
    outlined: false
    radius: 16
    pressed: iconTouch.pressed
    opacity: enabled ? 1 : 0.45

    border.width: 1
    border.color: active ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.08)

    GlyphIcon {
      anchors.centerIn: parent
      name: iconButton.iconName
      strokeColor: iconButton.active ? Theme.textOnAccent : Theme.textMuted
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
    implicitHeight: 42
    tone: "field"
    outlined: true
    radius: Theme.radiusSm
    pressed: expandTouch.pressed

    Row {
      anchors.fill: parent
      anchors.leftMargin: 12
      anchors.rightMargin: 12
      spacing: 8

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
        strokeColor: Theme.textMuted
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

    implicitWidth: 44
    implicitHeight: 44
    radius: width / 2
    tone: active ? "accent" : "field"
    outlined: false
    pressed: circleTouch.pressed

    border.width: 1
    border.color: active ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.08)

    GlyphIcon {
      anchors.centerIn: parent
      name: circleButton.iconName
      strokeColor: circleButton.active ? Theme.textOnAccent : Theme.text
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

    implicitWidth: 42
    implicitHeight: 42
    tone: "field"
    outlined: false
    radius: 16
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.08)

    GlyphIcon {
      anchors.centerIn: parent
      name: badge.iconName
      strokeColor: Theme.textMuted
    }
  }

  component QuickTile: UiSurface {
    id: tile

    property string iconName: "wifi"
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool expanded: false
    property bool expandable: true
    signal clicked()

    implicitWidth: parent ? Math.floor((parent.width - 8) / 2) : 180
    implicitHeight: 66
    tone: active ? "accent" : "field"
    outlined: false
    radius: 20
    pressed: tileTouch.pressed
    clip: true

    color: active ? Theme.accent : Theme.field
    border.width: 1
    border.color: active ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.08)

    gradient: Gradient {
      GradientStop { position: 0; color: tile.active ? Theme.accentStrong : Theme.field }
      GradientStop { position: 1; color: tile.active ? Theme.accent : Theme.panelRaised }
    }

    Rectangle {
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      width: tile.expandable ? 52 : 0
      radius: parent.radius
      color: tile.active ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.04)
      visible: tile.expandable
    }

    Row {
      anchors.fill: parent
      anchors.leftMargin: 14
      anchors.rightMargin: 14
      spacing: 10

      GlyphIcon {
        anchors.verticalCenter: parent.verticalCenter
        name: tile.iconName
        strokeColor: tile.active ? Theme.textOnAccent : Theme.textMuted
      }

      Column {
        width: Math.max(0, parent.width - (tile.expandable ? 68 : 36))
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        UiText {
          text: tile.title
          size: "sm"
          tone: tile.active ? "onAccent" : "primary"
          font.weight: Font.DemiBold
          elide: Text.ElideRight
        }

        UiText {
          text: tile.subtitle
          visible: text !== ""
          size: "xs"
          tone: tile.active ? "onAccent" : "muted"
          opacity: tile.active ? 0.88 : 0.92
          elide: Text.ElideRight
        }
      }

      GlyphIcon {
        anchors.verticalCenter: parent.verticalCenter
        visible: tile.expandable
        name: tile.expanded ? "chevron-down" : "chevron-right"
        strokeColor: tile.active ? Theme.textOnAccent : Theme.textSubtle
      }
    }

    MouseArea {
      id: tileTouch

      anchors.fill: parent
      onClicked: tile.clicked()
    }
  }

  component MediaSlider: Item {
    id: mediaSlider

    property string iconName: "speaker"
    property bool showIcon: true
    property real from: 0
    property real to: 1
    property real value: 0
    property string valueText: ""
    property bool showValueText: false
    signal valueMoved(real value)
    signal valueCommitted(real value)

    implicitWidth: parent ? parent.width : 0
    implicitHeight: 40

    Row {
      anchors.fill: parent
      spacing: 8

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
          enabled: mediaSlider.enabled

          Binding on value {
            when: !mediaControl.pressed
            value: mediaSlider.value
          }

          onMoved: function() {
            mediaSlider.valueMoved(mediaControl.value);
          }
          onPressedChanged: {
            if (!pressed) mediaSlider.valueCommitted(mediaControl.value);
          }

          background: Rectangle {
            x: mediaControl.leftPadding
            y: mediaControl.topPadding + mediaControl.availableHeight / 2 - height / 2
            width: mediaControl.availableWidth
            height: 4
            radius: 3
            color: Qt.rgba(1, 1, 1, 0.16)

            Rectangle {
              width: Math.max(parent.height, mediaControl.visualPosition * parent.width)
              height: parent.height
              radius: parent.radius
              color: Theme.accent
            }
          }

          handle: Rectangle {
            x: mediaControl.leftPadding + mediaControl.visualPosition * (mediaControl.availableWidth - width)
            y: mediaControl.topPadding + mediaControl.availableHeight / 2 - height / 2
            width: 16
            height: 16
            radius: 8
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
    signal valueMoved(real value)
    signal valueCommitted(real value)

    implicitWidth: parent ? parent.width : 0
    implicitHeight: 42

    UiSurface {
      anchors.fill: parent
      tone: "field"
      outlined: false
      radius: 16
      opacity: inlineSlider.enabled ? 1 : 0.45
      clip: true

      border.width: 1
      border.color: Qt.rgba(1, 1, 1, 0.08)

      Slider {
        id: slider

        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 5
        anchors.bottomMargin: 5
        from: inlineSlider.from
        to: inlineSlider.to
        stepSize: inlineSlider.stepSize
        enabled: inlineSlider.enabled
        leftPadding: titleLabel.implicitWidth + 28
        rightPadding: valueLabel.implicitWidth + 28

        Binding on value {
          when: !slider.pressed
          value: inlineSlider.value
        }

        onMoved: function() {
          inlineSlider.valueMoved(slider.value);
        }
        onPressedChanged: {
          if (!pressed) inlineSlider.valueCommitted(slider.value);
        }

        background: Rectangle {
          x: slider.leftPadding
          y: slider.topPadding + slider.availableHeight / 2 - height / 2
          width: slider.availableWidth
          height: 5
          radius: 3
          color: Qt.rgba(1, 1, 1, 0.14)

          Rectangle {
            width: Math.max(parent.height, slider.visualPosition * parent.width)
            height: parent.height
            radius: parent.radius
            color: Theme.accent
            opacity: inlineSlider.enabled ? 0.95 : 0.45
          }
        }

        handle: Rectangle {
          x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
          y: slider.topPadding + slider.availableHeight / 2 - height / 2
          width: 14
          height: 14
          radius: 7
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
    implicitHeight: 42
    tone: active ? "accent" : "field"
    outlined: false
    pressed: actionTouch.pressed
    opacity: enabled ? 1 : 0.45

    border.width: 1
    border.color: active ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.08)

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
    id: brightnessCommitTimer
    interval: 90
    repeat: false
    onTriggered: brightnessService.applyScreenPercent(root.pendingScreenBrightness)
  }

  Timer {
    id: keyboardCommitTimer
    interval: 90
    repeat: false
    onTriggered: brightnessService.applyKeyboardValue(keyboardBrightnessSlider.value)
  }

  UiSurface {
    id: panel

    width: root.implicitWidth
    implicitHeight: content.implicitHeight + 24
    tone: "panel"
    outlined: false
    radius: 28

    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.08)

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
        height: 44
        spacing: 8

        StatusChip {
          id: batteryChip
          visible: root.batteryAvailable
          anchors.verticalCenter: parent.verticalCenter
          text: root.batterySummary()
        }

        Item {
          width: Math.max(0, parent.width - (batteryChip.visible ? batteryChip.implicitWidth : 0) - sleepButton.implicitWidth - lockButton.implicitWidth - powerToggleButton.implicitWidth - 24)
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

      Row {
        width: parent.width
        height: 42
        spacing: 12

        IconBadge {
          id: brightnessBadge
          anchors.verticalCenter: parent.verticalCenter
          iconName: "sun"
        }

        MediaSlider {
          id: brightnessSlider

          width: parent.width - brightnessBadge.width - 12
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

      Row {
        width: parent.width
        height: 42
        spacing: 12

        IconButton {
          id: muteButton
          anchors.verticalCenter: parent.verticalCenter
          width: 42
          iconName: root.audioReady && root.audioNode.muted ? "speaker-muted" : "speaker"
          active: root.audioReady && root.audioNode.muted
          enabled: root.audioReady
          onClicked: {
            if (root.audioReady) root.audioNode.muted = !root.audioNode.muted;
          }
        }

        MediaSlider {
          width: parent.width - muteButton.width - outputButton.width - 24
          anchors.verticalCenter: parent.verticalCenter
          showIcon: false
          value: root.audioVolumeValue()
          enabled: root.audioReady
          onValueMoved: function(value) {
            if (root.audioReady) root.audioNode.volume = value;
          }
          onValueCommitted: function(value) {
            if (root.audioReady) root.audioNode.volume = value;
          }
        }

        IconButton {
          id: outputButton
          anchors.verticalCenter: parent.verticalCenter
          width: 42
          iconName: root.expandedSection === "outputs" ? "chevron-down" : "chevron-right"
          active: root.expandedSection === "outputs"
          enabled: Pipewire.ready
          onClicked: root.toggleSection("outputs")
        }
      }

      Column {
        width: parent.width
        spacing: 10

        Row {
          width: parent.width
          spacing: 8

          QuickTile {
            width: Math.floor((parent.width - parent.spacing) / 2)
            iconName: "wifi"
            title: root.wifiTileTitle()
            subtitle: root.wifiTileSubtitle()
            active: root.expandedSection === "wifi" || (wifiService.enabled && wifiService.connectedSsid !== "")
            expanded: root.expandedSection === "wifi"
            onClicked: root.toggleSection("wifi")
          }

          QuickTile {
            width: Math.floor((parent.width - parent.spacing) / 2)
            iconName: "bluetooth"
            title: root.bluetoothTileTitle()
            subtitle: root.bluetoothTileSubtitle()
            active: root.expandedSection === "bluetooth" || !!(root.bluetoothAdapter && root.bluetoothAdapter.enabled)
            expanded: root.expandedSection === "bluetooth"
            onClicked: root.toggleSection("bluetooth")
          }
        }

        Row {
          width: parent.width
          spacing: 8

          QuickTile {
            width: Math.floor((parent.width - parent.spacing) / 2)
            iconName: "gauge"
            title: root.profileShortLabel()
            subtitle: "Profile"
            active: true
            expanded: root.expandedSection === "profile"
            onClicked: root.toggleSection("profile")
          }

          QuickTile {
            width: Math.floor((parent.width - parent.spacing) / 2)
            iconName: brightnessService.keyboardAvailable ? "keyboard" : "power"
            title: brightnessService.keyboardAvailable ? root.keyboardTileTitle() : "Power"
            subtitle: brightnessService.keyboardAvailable ? root.keyboardTileSubtitle() : "Restart, lock"
            active: brightnessService.keyboardAvailable ? root.expandedSection === "keyboard" : root.expandedSection === "power"
            expanded: brightnessService.keyboardAvailable ? root.expandedSection === "keyboard" : root.expandedSection === "power"
            onClicked: root.toggleSection(brightnessService.keyboardAvailable ? "keyboard" : "power")
          }
        }

        QuickTile {
          width: parent.width
          visible: brightnessService.keyboardAvailable
          iconName: "power"
          title: "Power"
          subtitle: "Restart, lock"
          active: root.expandedSection === "power"
          expanded: root.expandedSection === "power"
          onClicked: root.toggleSection("power")
        }
      }

      UiSurface {
        visible: root.expandedSection === "keyboard" && brightnessService.keyboardAvailable
        width: parent.width
        implicitHeight: keyboardColumn.implicitHeight + 24
        tone: "raised"
        outlined: false
        radius: 20
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)

        Column {
          id: keyboardColumn

          width: parent.width - 24
          anchors.left: parent.left
          anchors.leftMargin: 12
          anchors.top: parent.top
          anchors.topMargin: 12
          spacing: 10

          UiText {
            text: "Keyboard Backlight"
            size: "sm"
            font.weight: Font.DemiBold
          }

          InlineSlider {
            id: keyboardBrightnessSlider
            width: parent.width
            title: "Keyboard"
            from: 0
            to: Math.max(1, brightnessService.keyboardMax)
            stepSize: 1
            valueText: `${brightnessService.keyboardPercent}%`
            value: brightnessService.keyboardValue
            onValueMoved: keyboardCommitTimer.restart()
            onValueCommitted: function(value) {
              keyboardCommitTimer.stop();
              brightnessService.applyKeyboardValue(value);
            }
          }
        }
      }

      UiSurface {
        visible: root.expandedSection === "profile"
        width: parent.width
        implicitHeight: profileColumn.implicitHeight + 24
        tone: "raised"
        outlined: false
        radius: 20
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)

        Column {
          id: profileColumn

          width: parent.width - 24
          anchors.left: parent.left
          anchors.leftMargin: 12
          anchors.top: parent.top
          anchors.topMargin: 12
          spacing: 10

          UiText {
            text: "Power Profile"
            size: "sm"
            font.weight: Font.DemiBold
          }

          Row {
            width: parent.width
            spacing: 8

            FlatButton {
              width: Math.floor((parent.width - 16) / 3)
              text: "Saver"
              active: PowerProfiles.profile === PowerProfile.PowerSaver
              onClicked: PowerProfiles.profile = PowerProfile.PowerSaver
            }

            FlatButton {
              width: Math.floor((parent.width - 16) / 3)
              text: "Balanced"
              active: PowerProfiles.profile === PowerProfile.Balanced
              onClicked: PowerProfiles.profile = PowerProfile.Balanced
            }

            FlatButton {
              width: Math.floor((parent.width - 16) / 3)
              text: "Perf"
              active: PowerProfiles.profile === PowerProfile.Performance
              enabled: PowerProfiles.hasPerformanceProfile
              onClicked: PowerProfiles.profile = PowerProfile.Performance
            }
          }
        }
      }

      UiSurface {
        visible: root.expandedSection === "outputs"
        width: parent.width
        implicitHeight: outputsColumn.implicitHeight + 24
        tone: "raised"
        outlined: false
        radius: 20
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)

        Column {
          id: outputsColumn

          width: parent.width - 24
          anchors.left: parent.left
          anchors.leftMargin: 12
          anchors.top: parent.top
          anchors.topMargin: 12
          spacing: 8

          UiText {
            text: "Audio Output"
            size: "sm"
            font.weight: Font.DemiBold
          }

          Repeater {
            model: Pipewire.nodes

            delegate: UiSurface {
              id: outputRow

              required property var modelData
              readonly property var outputNode: modelData
              readonly property bool shown: !!(outputNode && outputNode.audio && outputNode.isSink && !outputNode.isStream)

              visible: shown
              width: parent.width
              implicitHeight: shown ? 40 : 0
              height: shown ? implicitHeight : 0
              tone: root.audioSink === outputNode ? "accent" : "panelRaised"
              outlined: root.audioSink !== outputNode
              radius: Theme.radiusSm

              Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                GlyphIcon {
                  anchors.verticalCenter: parent.verticalCenter
                  name: "speaker"
                  strokeColor: root.audioSink === outputRow.outputNode ? Theme.textOnAccent : Theme.textMuted
                }

                UiText {
                  width: Math.max(0, parent.width - outputState.implicitWidth - 26)
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.outputLabel(outputRow.outputNode)
                  size: "sm"
                  tone: root.audioSink === outputRow.outputNode ? "onAccent" : "primary"
                  font.weight: Font.DemiBold
                  elide: Text.ElideRight
                }

                UiText {
                  id: outputState

                  anchors.verticalCenter: parent.verticalCenter
                  text: root.audioSink === outputRow.outputNode ? "Active" : "Use"
                  size: "xs"
                  tone: root.audioSink === outputRow.outputNode ? "onAccent" : "muted"
                  font.weight: Font.DemiBold
                }
              }

              MouseArea {
                anchors.fill: parent
                onClicked: Pipewire.preferredDefaultAudioSink = outputRow.outputNode
              }
            }
          }
        }
      }

      UiSurface {
        visible: root.expandedSection === "wifi"
        width: parent.width
        implicitHeight: wifiColumn.implicitHeight + 24
        tone: "raised"
        outlined: false
        radius: 20
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)

        Column {
          id: wifiColumn

          width: parent.width - 24
          anchors.left: parent.left
          anchors.leftMargin: 12
          anchors.top: parent.top
          anchors.topMargin: 12
          spacing: 8

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

          UiText {
            visible: !wifiService.hardwareEnabled
            text: "WiFi hardware is blocked."
            size: "xs"
            tone: "accent"
          }

          Repeater {
            model: wifiService.enabled ? Math.min(4, wifiService.networks.length) : 0

            delegate: UiSurface {
              id: wifiRow

              required property int index
              readonly property var network: wifiService.networks[index]

              width: parent.width
              implicitHeight: 42
              tone: network && network.active ? "accent" : "panelRaised"
              outlined: !network || !network.active
              radius: Theme.radiusSm
              pressed: wifiTouch.pressed

              Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                GlyphIcon {
                  anchors.verticalCenter: parent.verticalCenter
                  name: "wifi"
                  strokeColor: wifiRow.network && wifiRow.network.active ? Theme.textOnAccent : Theme.textMuted
                }

                Column {
                  width: Math.max(0, parent.width - wifiState.implicitWidth - 26)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: 1

                  UiText {
                    text: wifiRow.network ? wifiRow.network.ssid : ""
                    size: "sm"
                    tone: wifiRow.network && wifiRow.network.active ? "onAccent" : "primary"
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                  }

                  UiText {
                    text: wifiRow.network
                      ? `${wifiRow.network.signal}%${wifiRow.network.security !== "" ? `, ${wifiRow.network.security}` : ", open"}${wifiRow.network.known ? ", saved" : ""}`
                      : ""
                    size: "xs"
                    tone: wifiRow.network && wifiRow.network.active ? "onAccent" : "subtle"
                    elide: Text.ElideRight
                  }
                }

                UiText {
                  id: wifiState

                  anchors.verticalCenter: parent.verticalCenter
                  text: wifiRow.network && wifiRow.network.active ? "Connected" : "Connect"
                  size: "xs"
                  tone: wifiRow.network && wifiRow.network.active ? "onAccent" : "muted"
                  font.weight: Font.DemiBold
                }
              }

              MouseArea {
                id: wifiTouch

                anchors.fill: parent
                enabled: !!wifiRow.network && !wifiService.busy
                onClicked: root.beginWifiConnect(wifiRow.network)
              }
            }
          }

          UiSurface {
            visible: root.wifiPasswordTarget !== ""
            width: parent.width
            implicitHeight: passwordColumn.implicitHeight + 20
            tone: "panelRaised"
            outlined: true
            radius: Theme.radiusSm

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
                  radius: Theme.radiusSm
                  color: Theme.panel
                  border.width: 1
                  border.color: Theme.border
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
        }
      }

      UiSurface {
        visible: root.expandedSection === "bluetooth"
        width: parent.width
        implicitHeight: bluetoothColumn.implicitHeight + 24
        tone: "raised"
        outlined: false
        radius: 20
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)

        Column {
          id: bluetoothColumn

          width: parent.width - 24
          anchors.left: parent.left
          anchors.leftMargin: 12
          anchors.top: parent.top
          anchors.topMargin: 12
          spacing: 8

          Row {
            width: parent.width
            spacing: 8

            FlatButton {
              text: root.bluetoothAdapter && root.bluetoothAdapter.enabled ? "Turn Off" : "Turn On"
              enabled: !!root.bluetoothAdapter && root.bluetoothAdapter.state !== BluetoothAdapterState.Blocked
              onClicked: {
                if (root.bluetoothAdapter) root.bluetoothAdapter.enabled = !root.bluetoothAdapter.enabled;
              }
            }

            FlatButton {
              text: root.bluetoothAdapter && root.bluetoothAdapter.discovering ? "Stop Scan" : "Scan"
              enabled: !!root.bluetoothAdapter && root.bluetoothAdapter.enabled
              onClicked: {
                if (root.bluetoothAdapter) root.bluetoothAdapter.discovering = !root.bluetoothAdapter.discovering;
              }
            }
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

          Repeater {
            model: root.bluetoothAdapter && root.bluetoothAdapter.enabled ? root.bluetoothAdapter.devices : null

            delegate: UiSurface {
              id: connectedDeviceRow

              required property var modelData
              readonly property var device: modelData

              visible: device && device.connected
              width: parent.width
              implicitHeight: visible ? 42 : 0
              height: visible ? implicitHeight : 0
              tone: "accent"
              outlined: false
              radius: Theme.radiusSm
              clip: true

              Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                GlyphIcon {
                  anchors.verticalCenter: parent.verticalCenter
                  name: "bluetooth"
                  strokeColor: Theme.textOnAccent
                }

                Column {
                  width: Math.max(0, parent.width - deviceInfo.implicitWidth - 26)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: 1

                  UiText {
                    text: connectedDeviceRow.device.deviceName || connectedDeviceRow.device.name || connectedDeviceRow.device.address
                    size: "sm"
                    tone: "onAccent"
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                  }

                  UiText {
                    text: connectedDeviceRow.device.batteryAvailable
                      ? `${Math.round(connectedDeviceRow.device.battery)}% battery`
                      : "Connected"
                    size: "xs"
                    tone: "onAccent"
                    elide: Text.ElideRight
                  }
                }

                UiText {
                  id: deviceInfo

                  anchors.verticalCenter: parent.verticalCenter
                  text: connectedDeviceRow.device.state === BluetoothDeviceState.Connecting ? "Working" : "Disconnect"
                  size: "xs"
                  tone: "onAccent"
                  font.weight: Font.DemiBold
                }
              }

              MouseArea {
                anchors.fill: parent
                onClicked: connectedDeviceRow.device.disconnect()
              }
            }
          }

          Repeater {
            model: root.bluetoothAdapter && root.bluetoothAdapter.enabled ? root.bluetoothAdapter.devices : null

            delegate: UiSurface {
              id: otherDeviceRow

              required property var modelData
              readonly property var device: modelData

              visible: device && !device.connected
              width: parent.width
              implicitHeight: visible ? 42 : 0
              height: visible ? implicitHeight : 0
              tone: "panelRaised"
              outlined: true
              radius: Theme.radiusSm
              clip: true

              Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                GlyphIcon {
                  anchors.verticalCenter: parent.verticalCenter
                  name: "bluetooth"
                  strokeColor: Theme.textMuted
                }

                Column {
                  width: Math.max(0, parent.width - otherInfo.implicitWidth - 26)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: 1

                  UiText {
                    text: otherDeviceRow.device.deviceName || otherDeviceRow.device.name || otherDeviceRow.device.address
                    size: "sm"
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                  }

                  UiText {
                    text: otherDeviceRow.device.paired || otherDeviceRow.device.bonded ? "Paired" : "Available"
                    size: "xs"
                    tone: "subtle"
                    elide: Text.ElideRight
                  }
                }

                UiText {
                  id: otherInfo

                  anchors.verticalCenter: parent.verticalCenter
                  text: otherDeviceRow.device.pairing || otherDeviceRow.device.state === BluetoothDeviceState.Connecting
                    ? "Working"
                    : (otherDeviceRow.device.paired || otherDeviceRow.device.bonded ? "Connect" : "Pair")
                  size: "xs"
                  tone: "muted"
                  font.weight: Font.DemiBold
                }
              }

              MouseArea {
                anchors.fill: parent
                onClicked: {
                  if (otherDeviceRow.device.paired || otherDeviceRow.device.bonded) otherDeviceRow.device.connect();
                  else otherDeviceRow.device.pair();
                }
              }
            }
          }
        }
      }

      UiSurface {
        visible: root.expandedSection === "power"
        width: parent.width
        implicitHeight: powerColumn.implicitHeight + 24
        tone: "raised"
        outlined: false
        radius: 20
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)

        Column {
          id: powerColumn

          width: parent.width - 24
          anchors.left: parent.left
          anchors.leftMargin: 12
          anchors.top: parent.top
          anchors.topMargin: 12
          spacing: 8

          Grid {
            width: parent.width
            columns: 2
            rowSpacing: 8
            columnSpacing: 8

            ActionButton {
              width: Math.floor((parent.width - parent.columnSpacing) / parent.columns)
              title: "Lock"
              onClicked: sessionActions.lock()
            }

            ActionButton {
              width: Math.floor((parent.width - parent.columnSpacing) / parent.columns)
              title: "Sleep"
              onClicked: sessionActions.sleep()
            }

            ActionButton {
              width: Math.floor((parent.width - parent.columnSpacing) / parent.columns)
              title: root.powerActionLabel("logout", "Log Out")
              active: root.pendingPowerAction === "logout"
              onClicked: root.triggerPowerAction("logout")
            }

            ActionButton {
              width: Math.floor((parent.width - parent.columnSpacing) / parent.columns)
              title: root.powerActionLabel("restart", "Restart")
              active: root.pendingPowerAction === "restart"
              onClicked: root.triggerPowerAction("restart")
            }

            ActionButton {
              width: Math.floor((parent.width - parent.columnSpacing) / parent.columns)
              title: root.powerActionLabel("shutdown", "Shut Down")
              active: root.pendingPowerAction === "shutdown"
              onClicked: root.triggerPowerAction("shutdown")
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

      UiText {
        visible: brightnessService.lastError !== ""
        text: brightnessService.lastError
        size: "xs"
        tone: "accent"
        wrapMode: Text.WordWrap
      }
    }
  }
}
