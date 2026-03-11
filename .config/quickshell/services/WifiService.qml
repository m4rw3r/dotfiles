pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

Item {
  id: root

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

  function resetStatus() {
    enabled = false;
    hardwareEnabled = true;
  }

  function resetSaved() {
    savedNetworks = ({})
  }

  function resetWifiList() {
    connectedSsid = "";
    connectedSignal = 0;
    networks = [];
  }

  function resetRefreshState() {
    resetStatus();
    resetSaved();
    resetWifiList();
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

    if (refreshErrors.statusFailed) resetStatus();
    else parseStatus(statusBlock);

    const nextSavedNetworks = refreshErrors.savedFailed ? ({}) : parseSaved(savedBlock);
    savedNetworks = nextSavedNetworks;

    if (refreshErrors.wifiFailed) resetWifiList();
    else parseWifiList(wifiBlock, nextSavedNetworks);

    return refreshErrors;
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

  function refreshErrorText(refreshErrors, stderrText) {
    if (stderrText !== "") return stderrText;
    if (!refreshErrors) return "";
    if (refreshErrors.statusFailed && refreshErrors.savedFailed && refreshErrors.wifiFailed) return "Unable to refresh Wi-Fi state.";
    if (refreshErrors.statusFailed && refreshErrors.wifiFailed) return "Unable to refresh Wi-Fi status and networks.";
    if (refreshErrors.statusFailed && refreshErrors.savedFailed) return "Unable to refresh Wi-Fi status and saved networks.";
    if (refreshErrors.savedFailed && refreshErrors.wifiFailed) return "Unable to refresh saved networks and Wi-Fi networks.";
    if (refreshErrors.statusFailed) return "Unable to refresh Wi-Fi status.";
    if (refreshErrors.savedFailed) return "Unable to refresh saved Wi-Fi networks.";
    if (refreshErrors.wifiFailed) return "Unable to refresh Wi-Fi networks.";
    return "";
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

    return known;
  }

  function parseWifiList(text, knownNetworks) {
    const lines = String(text || "").split("\n");
    const deduped = {};
    const known = knownNetworks || {};
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
        known: known[ssid] === true
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
    id: refreshStdout
    waitForEnd: true
  }

  StdioCollector {
    id: refreshStderr
    waitForEnd: true
  }

  Process {
    id: refreshProcess

    stdout: refreshStdout
    stderr: refreshStderr

    Component.onCompleted: exited.connect(function(exitCode) {
      root.busy = false;
      root.ready = true;
      const stderrText = String(refreshStderr.text || "").trim();
      const stdoutText = refreshStdout.text;

      if (exitCode === 0 && root.hasRefreshPayload(stdoutText)) {
        const refreshErrors = root.parseRefresh(stdoutText);
        root.lastError = root.refreshErrorText(refreshErrors, stderrText);
        return;
      }

      root.resetRefreshState();
      root.lastError = stderrText !== "" ? stderrText : "Unable to refresh Wi-Fi state.";
    })
  }

  StdioCollector {
    id: toggleStderr
    waitForEnd: true
  }

  StdioCollector {
    id: scanStderr
    waitForEnd: true
  }

  StdioCollector {
    id: connectStderr
    waitForEnd: true
  }

  Process {
    id: toggleProcess
    stderr: toggleStderr

    Component.onCompleted: exited.connect(function(exitCode) {
      root.lastError = exitCode === 0 ? "" : String(toggleStderr.text || "").trim();
      root.refresh();
    })
  }

  Process {
    id: scanProcess
    stderr: scanStderr

    Component.onCompleted: exited.connect(function(exitCode) {
      root.lastError = exitCode === 0 ? "" : String(scanStderr.text || "").trim();
      rescanDelay.restart();
    })
  }

  Process {
    id: connectProcess
    stderr: connectStderr

    Component.onCompleted: exited.connect(function(exitCode) {
      root.lastError = exitCode === 0 ? "" : String(connectStderr.text || "").trim();
      if (exitCode !== 0) root.busy = false;
      root.pendingSsid = "";
      rescanDelay.restart();
    })
  }

  Timer {
    id: rescanDelay
    interval: 700
    repeat: false
    onTriggered: root.refresh()
  }
}
