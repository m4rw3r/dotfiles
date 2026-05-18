pragma ComponentBehavior: Bound

import QtQml
import QtQuick
import Quickshell.Networking

Item {
  id: root

  property bool ready: false
  readonly property bool enabled: Networking.wifiEnabled
  readonly property bool hardwareEnabled: Networking.wifiHardwareEnabled
  readonly property bool scanning: !!(currentWifiDevice && currentWifiDevice.scannerEnabled)
  readonly property bool busy: operationBusy || networkStateChanging
  property string connectedSsid: ""
  property int connectedSignal: 0
  property var networks: []
  property string lastError: ""
  property string lastErrorContext: ""
  property string lastErrorTargetSsid: ""
  property string pendingSsid: ""

  property var currentWifiDevice: null
  property bool networkStateChanging: false
  property bool operationBusy: false
  property bool pendingPasswordSubmitted: false

  readonly property string noAdapterError: "No Wi-Fi adapter found."

  Component.onCompleted: refresh()

  function clearLastError() {
    lastError = "";
    lastErrorContext = "";
    lastErrorTargetSsid = "";
  }

  function setLastError(message, context, targetSsid) {
    lastError = message;
    lastErrorContext = context || "";
    lastErrorTargetSsid = targetSsid || "";
  }

  function networkObjects(device) {
    if (!device || !device.networks || !device.networks.values)
      return [];
    return device.networks.values;
  }

  function wifiDevice() {
    const devices = Networking.devices && Networking.devices.values ? Networking.devices.values : [];
    for (let index = 0; index < devices.length; index += 1) {
      const device = devices[index];
      if (device && device.type === DeviceType.Wifi)
        return device;
    }
    return null;
  }

  function signalPercent(network) {
    return Math.max(0, Math.min(100, Math.round(Number(network.signalStrength || 0) * 100)));
  }

  function isOpenLikeSecurity(security) {
    return security === WifiSecurityType.Open || security === WifiSecurityType.Owe;
  }

  function isPskSecurity(security) {
    return security === WifiSecurityType.WpaPsk || security === WifiSecurityType.Wpa2Psk || security === WifiSecurityType.Sae;
  }

  function securityLabel(network) {
    if (!network || network.security === WifiSecurityType.Open)
      return "";
    return WifiSecurityType.toString(network.security);
  }

  function secureFor(network) {
    return !!network && !isOpenLikeSecurity(network.security);
  }

  function passwordRequiredFor(network) {
    return !!network && !network.known && isPskSecurity(network.security);
  }

  function unsupportedPasswordSecurityFor(network) {
    return !!network && !network.known && !isOpenLikeSecurity(network.security) && !isPskSecurity(network.security);
  }

  function networkName(network) {
    return String(network && network.name !== undefined ? network.name : "");
  }

  function targetSsid(target) {
    if (typeof target === "string")
      return target;
    try {
      if (target && target.ssid !== undefined)
        return String(target.ssid || "");
      if (target && target.name !== undefined)
        return String(target.name || "");
    } catch (error) {
      return "";
    }
    return "";
  }

  function networkFromTarget(target, password) {
    if (target && typeof target !== "string") {
      try {
        if (target.sourceNetwork)
          return target.sourceNetwork;
        if (target.name !== undefined && target.connect)
          return target;
      } catch (error) {
        return networkForSsid(targetSsid(target), password);
      }
    }

    return networkForSsid(targetSsid(target), password);
  }

  function betterConnectionTarget(candidate, current, password) {
    if (!current)
      return true;
    if (candidate.connected !== current.connected)
      return candidate.connected;
    if (candidate.known !== current.known)
      return candidate.known;
    if (password !== "" && isPskSecurity(candidate.security) !== isPskSecurity(current.security))
      return isPskSecurity(candidate.security);
    return signalPercent(candidate) > signalPercent(current);
  }

  function networkForSsid(ssid, password) {
    if (ssid === "")
      return null;

    const device = currentWifiDevice || wifiDevice();
    const candidates = networkObjects(device);
    let match = null;
    for (let index = 0; index < candidates.length; index += 1) {
      const network = candidates[index];
      if (!network || networkName(network) !== ssid)
        continue;
      if (betterConnectionTarget(network, match, password))
        match = network;
    }
    return match;
  }

  function networkList(device) {
    const sourceNetworks = networkObjects(device);
    const deduped = {};

    for (let index = 0; index < sourceNetworks.length; index += 1) {
      const sourceNetwork = sourceNetworks[index];
      const ssid = networkName(sourceNetwork);
      if (ssid === "")
        continue;

      const row = {
        active: !!sourceNetwork.connected,
        bssid: "",
        ssid,
        signal: signalPercent(sourceNetwork),
        security: securityLabel(sourceNetwork),
        secure: secureFor(sourceNetwork),
        known: !!sourceNetwork.known,
        sourceNetwork,
        securityType: sourceNetwork.security,
        passwordRequired: passwordRequiredFor(sourceNetwork),
        passwordConnectSupported: isPskSecurity(sourceNetwork.security),
        unsupportedSecurity: unsupportedPasswordSecurityFor(sourceNetwork)
      };

      const key = `${ssid}\u0000${sourceNetwork.security}`;
      const existing = deduped[key];
      if (!existing || row.signal > existing.signal || (row.active && !existing.active) || (row.known && !existing.known))
        deduped[key] = row;
    }

    const nextNetworks = Object.values(deduped);
    nextNetworks.sort((left, right) => {
      if (left.active !== right.active)
        return left.active ? -1 : 1;
      if (left.known !== right.known)
        return left.known ? -1 : 1;
      if (left.signal !== right.signal)
        return right.signal - left.signal;
      const byName = left.ssid.localeCompare(right.ssid);
      if (byName !== 0)
        return byName;
      return String(left.bssid || "").localeCompare(String(right.bssid || ""));
    });

    return nextNetworks;
  }

  function clearRecoveredError(activeSsid, availableNetworkCount, changing) {
    if (lastError === "" || pendingSsid !== "" || changing)
      return;

    if (lastErrorContext === "connect" || lastErrorContext === "password" || lastErrorContext === "unsupported") {
      if (activeSsid !== "" && (lastErrorTargetSsid === "" || activeSsid === lastErrorTargetSsid))
        clearLastError();
      return;
    }

    if (lastErrorContext !== "adapter" && enabled && hardwareEnabled && currentWifiDevice && (activeSsid !== "" || availableNetworkCount > 0))
      clearLastError();
  }

  function refresh() {
    const device = wifiDevice();
    currentWifiDevice = device;
    ready = true;

    if (!device) {
      connectedSsid = "";
      connectedSignal = 0;
      networks = [];
      networkStateChanging = false;
      setLastError(noAdapterError, "adapter", "");
      return;
    }

    if (lastErrorContext === "adapter")
      clearLastError();

    if (!enabled || !hardwareEnabled) {
      connectedSsid = "";
      connectedSignal = 0;
      networks = [];
      networkStateChanging = false;
      return;
    }

    const nextNetworks = networkList(device);
    const sourceNetworks = networkObjects(device);
    let activeSsid = "";
    let activeSignal = 0;
    let changing = false;
    let pendingChanging = false;

    for (let index = 0; index < nextNetworks.length; index += 1) {
      const row = nextNetworks[index];
      if (row.active && (activeSsid === "" || row.signal > activeSignal)) {
        activeSsid = row.ssid;
        activeSignal = row.signal;
      }
    }

    for (let index = 0; index < sourceNetworks.length; index += 1) {
      const network = sourceNetworks[index];
      if (network && network.stateChanging) {
        changing = true;
        if (networkName(network) === pendingSsid)
          pendingChanging = true;
      }
    }

    connectedSsid = activeSsid;
    connectedSignal = activeSignal;
    networks = nextNetworks;
    networkStateChanging = changing;
    clearRecoveredError(activeSsid, nextNetworks.length, changing);

    if (pendingSsid !== "" && connectedSsid === pendingSsid) {
      pendingSsid = "";
      pendingPasswordSubmitted = false;
      operationBusy = false;
      clearLastError();
    } else if (pendingSsid !== "" && !operationBusy && !pendingChanging) {
      pendingSsid = "";
      pendingPasswordSubmitted = false;
    }
  }

  function showMenu() {
    refresh();
    if (enabled && hardwareEnabled && currentWifiDevice)
      scan();
  }

  function scan() {
    const device = currentWifiDevice || wifiDevice();

    if (!device) {
      refresh();
      setLastError(noAdapterError, "adapter", "");
      return;
    }

    if (!enabled || !hardwareEnabled) {
      refresh();
      return;
    }

    clearLastError();
    try {
      device.scannerEnabled = true;
      scanTimer.restart();
      refresh();
    } catch (error) {
      setLastError(`Unable to scan Wi-Fi networks: ${error}`, "scan", "");
    }
  }

  function setEnabledState(nextState) {
    operationBusy = true;
    operationTimer.restart();
    clearLastError();
    try {
      Networking.wifiEnabled = nextState;
      if (!nextState && currentWifiDevice)
        currentWifiDevice.scannerEnabled = false;
    } catch (error) {
      operationBusy = false;
      setLastError(`Unable to ${nextState ? "enable" : "disable"} Wi-Fi: ${error}`, "toggle", "");
    }
    refresh();
  }

  function connectNetwork(target, password) {
    const submittedPassword = String(password || "");
    const ssid = targetSsid(target);
    if (ssid === "")
      return;

    const network = networkFromTarget(target, submittedPassword);
    if (!network) {
      pendingSsid = "";
      pendingPasswordSubmitted = false;
      operationBusy = false;
      setLastError(`${ssid} is no longer available.`, "connect", ssid);
      return;
    }

    const security = network.security;
    let connectAction = null;

    if (network.known || isOpenLikeSecurity(security)) {
      connectAction = function () {
        network.connect();
      };
    } else if (isPskSecurity(security) && submittedPassword !== "") {
      connectAction = function () {
        network.connectWithPsk(submittedPassword);
      };
    } else if (isPskSecurity(security)) {
      pendingSsid = "";
      pendingPasswordSubmitted = false;
      operationBusy = false;
      setLastError(`Password required for ${ssid}.`, "password", ssid);
      return;
    } else {
      pendingSsid = "";
      pendingPasswordSubmitted = false;
      operationBusy = false;
      setLastError(`Connection for ${WifiSecurityType.toString(security)} networks is not supported yet.`, "unsupported", ssid);
      return;
    }

    pendingSsid = networkName(network);
    pendingPasswordSubmitted = submittedPassword !== "";
    operationBusy = true;
    operationTimer.restart();
    clearLastError();

    try {
      connectAction();
    } catch (error) {
      pendingSsid = "";
      pendingPasswordSubmitted = false;
      operationBusy = false;
      setLastError(`Unable to connect to ${ssid}: ${error}`, "connect", ssid);
    }
    Qt.callLater(function () {
      root.refresh();
    });
  }

  function connectionFailureText(reason) {
    if (reason === ConnectionFailReason.NoSecrets)
      return "";
    if (reason === ConnectionFailReason.WifiAuthTimeout)
      return "Wi-Fi authentication timed out.";
    if (reason === ConnectionFailReason.WifiNetworkLost)
      return "Wi-Fi network lost.";
    if (reason === ConnectionFailReason.WifiClientDisconnected)
      return "Wi-Fi client disconnected.";
    if (reason === ConnectionFailReason.WifiClientFailed)
      return "Wi-Fi client failed.";

    const reasonLabel = ConnectionFailReason.toString(reason);
    if (reasonLabel && reasonLabel !== "Unknown")
      return `Connection failed: ${reasonLabel}.`;
    return "Unable to connect.";
  }

  function handleConnectionFailed(network, reason) {
    const ssid = networkName(network);
    const targetName = ssid !== "" ? ssid : pendingSsid;
    const passwordSubmitted = pendingPasswordSubmitted;

    if (pendingSsid === "" || pendingSsid === targetName) {
      pendingSsid = "";
      pendingPasswordSubmitted = false;
    }
    operationBusy = false;
    refresh();

    if (reason === ConnectionFailReason.NoSecrets)
      setLastError(passwordSubmitted ? `Incorrect or missing password for ${targetName}.` : `Password required for ${targetName}.`, "connect", targetName);
    else
      setLastError(`${targetName}: ${connectionFailureText(reason)}`, "connect", targetName);
  }

  Connections {
    target: Networking

    function onWifiEnabledChanged() {
      root.refresh();
    }

    function onWifiHardwareEnabledChanged() {
      root.refresh();
    }
  }

  Connections {
    target: Networking.devices
    ignoreUnknownSignals: true

    function onValuesChanged() {
      Qt.callLater(root.refresh);
    }

    function onObjectInsertedPost() {
      Qt.callLater(root.refresh);
    }

    function onObjectRemovedPost() {
      Qt.callLater(root.refresh);
    }
  }

  Connections {
    target: root.currentWifiDevice
    ignoreUnknownSignals: true

    function onScannerEnabledChanged() {
      root.refresh();
    }

    function onConnectedChanged() {
      root.refresh();
    }

    function onStateChanged() {
      root.refresh();
    }
  }

  Connections {
    target: root.currentWifiDevice && root.currentWifiDevice.networks ? root.currentWifiDevice.networks : null
    ignoreUnknownSignals: true

    function onValuesChanged() {
      Qt.callLater(root.refresh);
    }

    function onObjectInsertedPost() {
      Qt.callLater(root.refresh);
    }

    function onObjectRemovedPost() {
      Qt.callLater(root.refresh);
    }
  }

  Instantiator {
    model: root.currentWifiDevice && root.currentWifiDevice.networks ? root.currentWifiDevice.networks : null

    delegate: Item {
      required property var modelData

      readonly property var network: modelData
      readonly property var service: root

      visible: false

      Connections {
        target: network
        ignoreUnknownSignals: true

        function onConnectionFailed(reason) {
          service.handleConnectionFailed(network, reason);
        }

        function onConnectedChanged() {
          Qt.callLater(service.refresh);
        }

        function onKnownChanged() {
          Qt.callLater(service.refresh);
        }

        function onStateChanged() {
          Qt.callLater(service.refresh);
        }

        function onStateChangingChanged() {
          Qt.callLater(service.refresh);
        }

        function onSignalStrengthChanged() {
          Qt.callLater(service.refresh);
        }

        function onSecurityChanged() {
          Qt.callLater(service.refresh);
        }
      }
    }
  }

  Timer {
    id: scanTimer
    interval: 7000
    repeat: false
    onTriggered: {
      if (root.currentWifiDevice)
        root.currentWifiDevice.scannerEnabled = false;
      root.refresh();
    }
  }

  Timer {
    id: operationTimer
    interval: 1200
    repeat: false
    onTriggered: {
      root.operationBusy = false;
      root.refresh();
    }
  }
}
