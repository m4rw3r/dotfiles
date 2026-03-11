pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

Item {
  id: root

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
    id: stateStdout
    waitForEnd: true
  }

  StdioCollector {
    id: stateStderr
    waitForEnd: true
  }

  Process {
    id: stateReadProcess

    stdout: stateStdout
    stderr: stateStderr

    Component.onCompleted: exited.connect(function(exitCode) {
      root.settled = true;
      if (exitCode === 0) {
        root.parseState(stateStdout.text);
        return;
      }

      root.commandAvailable = exitCode !== 127;
      root.available = false;
      root.level = "off";
      root.lastError = exitCode === 127
        ? ""
        : (exitCode === 66 ? "Lighting state unavailable." : String(stateStderr.text || "").trim());
    })
  }

  StdioCollector {
    id: writeStderr
    waitForEnd: true
  }

  Process {
    id: lightingWriteProcess

    stderr: writeStderr

    Component.onCompleted: exited.connect(function(exitCode) {
      root.lastError = exitCode === 0 ? "" : String(writeStderr.text || "").trim();
      refreshTimer.restart();
    })
  }

  Timer {
    id: refreshTimer
    interval: 150
    repeat: false
    onTriggered: root.refresh()
  }
}
