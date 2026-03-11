pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

Item {
  id: root

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
      root.lastError = exitCode === 0 ? "" : String(detectStderr.text || "").trim();
      if (exitCode === 0) root.parseDeviceList(detectStdout.text);
      else root.settled = true;
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
      root.settled = true;
      if (exitCode === 0) root.parseBrightness(screenStdout.text, false);
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
      if (exitCode === 0) root.parseBrightness(keyboardStdout.text, true);
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
      root.lastError = exitCode === 0 ? "" : String(screenWriteStderr.text || "").trim();
      root.refreshScreen();
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
      root.lastError = exitCode === 0 ? "" : String(keyboardWriteStderr.text || "").trim();
      root.refreshKeyboard();
    })
  }
}
