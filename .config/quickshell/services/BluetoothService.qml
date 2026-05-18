pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Quickshell.Bluetooth

Item {
  id: root

  property string adapterKey: "defaultAdapter"
  property var adapter: null
  readonly property var devices: adapter && adapter.devices ? adapter.devices.values : []
  readonly property bool blocked: !!adapter && adapter.state === BluetoothAdapterState.Blocked
  readonly property bool enabled: !!(adapter && adapter.enabled)
  readonly property bool discovering: !!(adapter && adapter.discovering)
  readonly property int connectedCount: countDevices(true)
  readonly property int availableCount: countDevices(false)
  readonly property bool unblockAvailable: blocked && blockStateKnown && !hardBlocked

  property bool busy: false
  property bool blockStateKnown: false
  property bool blockStateRefreshing: false
  property bool blockStateRefreshQueued: false
  property bool hardBlocked: false
  property int unblockVerificationAttempts: 0
  property string lastError: ""

  readonly property int unblockVerificationMaxAttempts: 12

  Component.onCompleted: {
    adapter = currentAdapter();
    refreshBlockState();
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

  function parseBlockState(text) {
    let nextKnown = false;
    let nextHardBlocked = false;

    try {
      const payload = JSON.parse(String(text || "{}"));
      const devices = payload && payload.rfkilldevices ? payload.rfkilldevices : [];

      for (let i = 0; i < devices.length; i += 1) {
        const device = devices[i];
        if (!device || device.type !== "bluetooth") continue;

        nextKnown = true;
        if (device.hard === "blocked" || device.hard === true || device.hard === 1 || device.hard === "1")
          nextHardBlocked = true;
      }
    } catch (error) {
      blockStateKnown = false;
      hardBlocked = false;
      if (lastError === "") lastError = `Unable to parse Bluetooth block state: ${error}`;
      return;
    }

    blockStateKnown = nextKnown;
    hardBlocked = nextHardBlocked;
  }

  function refreshBlockState() {
    if (!blocked) {
      blockStateRefreshQueued = false;
      blockStateKnown = !!adapter;
      hardBlocked = false;
      return;
    }

    if (blockStateRefreshing) {
      blockStateRefreshQueued = true;
      return;
    }

    blockStateRefreshing = true;
    blockStateProcess.exec(["rfkill", "--json", "--output", "TYPE,SOFT,HARD,DEVICE", "list", "bluetooth"]);
  }

  function beginUnblockVerification() {
    unblockVerificationAttempts = 0;
    verifyUnblock();
  }

  function verifyUnblock() {
    if (!adapter) {
      busy = false;
      lastError = "No Bluetooth adapter found.";
      return;
    }

    refreshBlockState();

    if (blocked) {
      unblockVerificationAttempts += 1;
      if (unblockVerificationAttempts < unblockVerificationMaxAttempts) {
        unblockVerificationTimer.restart();
        return;
      }

      busy = false;
      if (!hardBlocked) lastError = "Bluetooth is still blocked after the unblock attempt.";
      return;
    }

    if (!adapter.enabled) adapter.enabled = true;
    busy = false;
    lastError = "";
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

    lastError = "";

    if (blocked) {
      if (!blockStateKnown) {
        refreshBlockState();
        return;
      }
      if (hardBlocked) {
        lastError = "Bluetooth is blocked by hardware or firmware airplane mode.";
        return;
      }

      busy = true;
      unblockProcess.exec(["rfkill", "unblock", "bluetooth"]);
      return;
    }

    const nextEnabled = !adapter.enabled;
    adapter.enabled = nextEnabled;
    if (!nextEnabled) stopDiscovery();
  }

  Connections {
    target: Bluetooth
    ignoreUnknownSignals: true

    function onDefaultAdapterChanged() {
      root.adapter = root.currentAdapter();
      root.refreshBlockState();
    }
  }

  Connections {
    target: root.adapter
    ignoreUnknownSignals: true

    function onStateChanged() {
      root.refreshBlockState();
    }
  }

  StdioCollector {
    id: blockStateStdout
    waitForEnd: true
  }

  StdioCollector {
    id: blockStateStderr
    waitForEnd: true
  }

  Process {
    id: blockStateProcess

    stdout: blockStateStdout
    stderr: blockStateStderr

    Component.onCompleted: exited.connect(function(exitCode) {
      root.blockStateRefreshing = false;

      if (!root.blocked) {
        root.blockStateKnown = !!root.adapter;
        root.hardBlocked = false;
      } else if (exitCode === 0) {
        root.parseBlockState(blockStateStdout.text);
      } else {
        const stderrText = String(blockStateStderr.text || "").trim();
        root.blockStateKnown = false;
        root.hardBlocked = false;
        if (root.lastError === "")
          root.lastError = stderrText !== "" ? stderrText : "Unable to inspect Bluetooth block state.";
      }

      if (root.blockStateRefreshQueued) {
        root.blockStateRefreshQueued = false;
        root.refreshBlockState();
      }
    })
  }

  StdioCollector {
    id: unblockStderr
    waitForEnd: true
  }

  Process {
    id: unblockProcess

    stderr: unblockStderr

    Component.onCompleted: exited.connect(function(exitCode) {
      const stderrText = String(unblockStderr.text || "").trim();

      if (exitCode === 0) {
        root.lastError = "";
        root.beginUnblockVerification();
        return;
      }

      root.busy = false;
      root.lastError = stderrText !== "" ? stderrText : "Unable to unblock Bluetooth.";
    })
  }

  Timer {
    id: unblockVerificationTimer
    interval: 250
    repeat: false

    onTriggered: root.verifyUnblock()
  }
}
