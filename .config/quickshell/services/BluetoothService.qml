pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Quickshell.Bluetooth

Item {
  id: root

  property string adapterKey: "defaultAdapter"
  property var adapter: null
  readonly property var devices: adapter && adapter.devices ? adapter.devices.values : []
  readonly property bool blocked: !!adapter
    && (adapter.state === BluetoothAdapterState.Blocked || softBlocked || hardBlocked)
  readonly property bool enabled: !!(adapter && adapter.enabled)
  readonly property bool discovering: !!(adapter && adapter.discovering)
  readonly property int connectedCount: countDevices(true)
  readonly property int availableCount: countDevices(false)

  property bool busy: false
  property bool enableAfterUnblock: false
  property bool rfkillKnown: false
  property bool rfkillRefreshing: false
  property bool rfkillRefreshQueued: false
  property bool softBlocked: false
  property bool hardBlocked: false
  property bool lastErrorFromRefresh: false
  property string lastError: ""

  Component.onCompleted: {
    adapter = currentAdapter();
    refreshRfkillState();
  }

  function currentAdapter() {
    return Bluetooth[adapterKey];
  }

  function countDevices(connected) {
    if (!adapter || !adapter.enabled) return 0;

    let count = 0;
    for (let i = 0; i < devices.length; i += 1) {
      const device = devices[i];
      if (!!(device && device.connected) === connected) count += 1;
    }

    return count;
  }

  function rfkillCommand(prefix) {
    const scriptPrefix = prefix || "";
    const script = `${scriptPrefix}for d in /sys/class/rfkill/rfkill*; do [ -r "$d/type" ] || continue; type=$(cat "$d/type"); [ "$type" = "bluetooth" ] || continue; name=$(cat "$d/name" 2>/dev/null || printf ''); soft=$(cat "$d/soft" 2>/dev/null || printf '0'); hard=$(cat "$d/hard" 2>/dev/null || printf '0'); printf '%s\t%s\t%s\n' "$name" "$soft" "$hard"; done`;
    return ["sh", "-lc", script];
  }

  function parseRfkillState(text) {
    let nextSoftBlocked = false;
    let nextHardBlocked = false;

    const lines = String(text || "").split("\n");
    for (let i = 0; i < lines.length; i += 1) {
      const line = lines[i].trim();
      if (line === "") continue;

      const fields = line.split("\t");
      if (fields.length < 3) continue;

      if (fields[1] === "1") nextSoftBlocked = true;
      if (fields[2] === "1") nextHardBlocked = true;
    }

    softBlocked = nextSoftBlocked;
    hardBlocked = nextHardBlocked;
    rfkillKnown = true;
  }

  function refreshRfkillState() {
    if (rfkillRefreshing) {
      rfkillRefreshQueued = true;
      return;
    }

    rfkillRefreshing = true;
    rfkillStateProcess.exec(rfkillCommand(""));
  }

  function stopDiscovery() {
    if (adapter) adapter.discovering = false;
  }

  function setDiscoveryEnabled(enabled) {
    if (!adapter) return;
    adapter.discovering = enabled;
  }

  function toggleEnabled() {
    if (!adapter || busy) return;

    lastErrorFromRefresh = false;
    lastError = "";

    if (hardBlocked) {
      lastErrorFromRefresh = false;
      lastError = "Bluetooth is hard blocked by hardware or firmware airplane mode.";
      refreshRfkillState();
      return;
    }

    if (blocked) {
      busy = true;
      enableAfterUnblock = true;
      unblockProcess.exec(rfkillCommand("rfkill unblock bluetooth && "));
      return;
    }

    adapter.enabled = !adapter.enabled;
    if (!adapter.enabled) stopDiscovery();
    refreshRfkillState();
  }

  Connections {
    target: Bluetooth
    ignoreUnknownSignals: true

    function onDefaultAdapterChanged() {
      root.adapter = root.currentAdapter();
      root.refreshRfkillState();
    }
  }

  Connections {
    target: root.adapter
    ignoreUnknownSignals: true

    function onStateChanged() {
      root.refreshRfkillState();
    }

    function onEnabledChanged() {
      root.refreshRfkillState();
    }
  }

  StdioCollector {
    id: rfkillStateStdout
    waitForEnd: true
  }

  StdioCollector {
    id: rfkillStateStderr
    waitForEnd: true
  }

  Process {
    id: rfkillStateProcess

    stdout: rfkillStateStdout
    stderr: rfkillStateStderr

    Component.onCompleted: exited.connect(function(exitCode) {
      root.rfkillRefreshing = false;

      const stderrText = String(rfkillStateStderr.text || "").trim();
      const stdoutText = rfkillStateStdout.text;

      if (exitCode === 0) {
        root.parseRfkillState(stdoutText);
        if (root.lastErrorFromRefresh) {
          root.lastError = "";
          root.lastErrorFromRefresh = false;
        }
      } else {
        root.rfkillKnown = false;
        root.softBlocked = false;
        root.hardBlocked = false;
        if (root.lastError === "") {
          root.lastErrorFromRefresh = true;
          root.lastError = stderrText !== "" ? stderrText : "Unable to inspect Bluetooth block state.";
        }
      }

      if (root.rfkillRefreshQueued) {
        root.rfkillRefreshQueued = false;
        root.refreshRfkillState();
      }
    })
  }

  StdioCollector {
    id: unblockStdout
    waitForEnd: true
  }

  StdioCollector {
    id: unblockStderr
    waitForEnd: true
  }

  Process {
    id: unblockProcess

    stdout: unblockStdout
    stderr: unblockStderr

    Component.onCompleted: exited.connect(function(exitCode) {
      root.busy = false;
      root.enableAfterUnblock = false;

      const stderrText = String(unblockStderr.text || "").trim();
      const stdoutText = unblockStdout.text;

      if (exitCode === 0) {
        root.parseRfkillState(stdoutText);

        if (root.hardBlocked) {
          root.lastErrorFromRefresh = false;
          root.lastError = "Bluetooth is hard blocked by hardware or firmware airplane mode.";
          return;
        }

        if (root.softBlocked) {
          root.lastErrorFromRefresh = false;
          root.lastError = "Bluetooth is still soft blocked after the unblock attempt.";
          return;
        }

        root.lastErrorFromRefresh = false;
        root.lastError = "";
        if (root.adapter) root.adapter.enabled = true;
        root.refreshRfkillState();
        return;
      }

      root.lastErrorFromRefresh = false;
      root.lastError = stderrText !== "" ? stderrText : "Unable to unblock Bluetooth.";
      root.refreshRfkillState();
    })
  }
}
