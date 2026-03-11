pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

Item {
  id: root

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

  StdioCollector {
    id: readStdout
    waitForEnd: true
  }

  StdioCollector {
    id: readStderr
    waitForEnd: true
  }

  Process {
    id: readProcess

    stdout: readStdout
    stderr: readStderr

    Component.onCompleted: exited.connect(function(exitCode) {
      root.settled = true;
      root.lastError = exitCode === 0 ? "" : String(readStderr.text || "").trim();
      if (exitCode === 0) root.parseState(readStdout.text);
      else root.ready = false;
    })
  }

  StdioCollector {
    id: writeStderr
    waitForEnd: true
  }

  StdioCollector {
    id: muteStderr
    waitForEnd: true
  }

  Process {
    id: writeProcess

    stderr: writeStderr

    Component.onCompleted: exited.connect(function(exitCode) {
      root.lastError = exitCode === 0 ? "" : String(writeStderr.text || "").trim();
      refreshTimer.restart();
    })
  }

  Process {
    id: muteProcess

    stderr: muteStderr

    Component.onCompleted: exited.connect(function(exitCode) {
      root.lastError = exitCode === 0 ? "" : String(muteStderr.text || "").trim();
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
