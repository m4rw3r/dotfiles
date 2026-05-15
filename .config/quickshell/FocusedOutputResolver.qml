pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var activeScreen: null
  property string activeScreenName: ""
  property int activeScreenIndexHint: -1
  property int deadlineMs: 90
  property int requestSerial: 0
  property int pendingRequestId: 0

  signal resolved(int requestId, var screen)

  function screenName(screen) {
    return screen && screen.name ? String(screen.name) : "";
  }

  function indexOfScreen(screen) {
    const screens = Quickshell.screens;
    for (let i = 0; i < screens.length; i += 1) {
      if (screens[i] === screen)
        return i;
    }

    return -1;
  }

  function screenByName(name) {
    if (name === "")
      return null;

    const screens = Quickshell.screens;
    for (let i = 0; i < screens.length; i += 1) {
      if (screenName(screens[i]) === name)
        return screens[i];
    }

    return null;
  }

  function remember(screen) {
    if (!screen)
      return;

    const index = indexOfScreen(screen);
    if (index >= 0)
      activeScreenIndexHint = index;

    const name = screenName(screen);
    if (name !== "")
      activeScreenName = name;
  }

  function resolveScreen(preferredScreen) {
    const screens = Quickshell.screens;
    if (screens.length === 0)
      return null;

    if (preferredScreen && indexOfScreen(preferredScreen) >= 0)
      return preferredScreen;
    if (activeScreen && indexOfScreen(activeScreen) >= 0)
      return activeScreen;

    const namedScreen = screenByName(activeScreenName);
    if (namedScreen)
      return namedScreen;

    if (activeScreenIndexHint >= 0)
      return screens[Math.min(activeScreenIndexHint, screens.length - 1)];
    return screens[0];
  }

  function ensureActiveScreen(preferredScreen) {
    const nextScreen = resolveScreen(preferredScreen);
    activeScreen = nextScreen;
    remember(nextScreen);
    return nextScreen;
  }

  function parseResponse(text) {
    const payload = String(text || "");
    const newlineIndex = payload.indexOf("\n");
    const requestLine = newlineIndex >= 0 ? payload.slice(0, newlineIndex) : payload;
    const responsePayload = newlineIndex >= 0 ? payload.slice(newlineIndex + 1).trim() : "";
    const requestId = Number(requestLine.trim());

    if (!Number.isInteger(requestId) || requestId <= 0)
      return {
        requestId: 0,
        screen: null
      };
    if (responsePayload === "")
      return {
        requestId,
        screen: null
      };

    try {
      const parsed = JSON.parse(responsePayload);
      return {
        requestId,
        screen: screenByName(parsed && parsed.name ? String(parsed.name) : "")
      };
    } catch (error) {
      return {
        requestId,
        screen: null
      };
    }
  }

  function finish(requestId, preferredScreen) {
    if (requestId === 0 || requestId !== pendingRequestId)
      return;
    pendingRequestId = 0;
    lookupTimer.stop();
    resolved(requestId, ensureActiveScreen(preferredScreen));
  }

  function request() {
    requestSerial += 1;
    const requestId = requestSerial;
    pendingRequestId = requestId;

    if (Quickshell.screens.length === 0) {
      Qt.callLater(function () {
        root.finish(requestId, null);
      });
      return requestId;
    }

    lookupTimer.restart();
    lookupProcess.exec(["sh", "-lc", `printf '%s\\n' ${requestId}; exec niri msg -j focused-output`]);
    return requestId;
  }

  function cancel() {
    pendingRequestId = 0;
    lookupTimer.stop();
  }

  Connections {
    target: Quickshell

    function onScreensChanged() {
      root.ensureActiveScreen();
    }
  }

  StdioCollector {
    id: lookupStdout
    waitForEnd: true
  }

  StdioCollector {
    id: lookupStderr
    waitForEnd: true
  }

  Process {
    id: lookupProcess

    stdout: lookupStdout
    stderr: lookupStderr

    Component.onCompleted: exited.connect(function (exitCode) {
      const response = root.parseResponse(lookupStdout.text);
      root.finish(response.requestId, exitCode === 0 ? response.screen : null);
    })
  }

  Timer {
    id: lookupTimer
    interval: root.deadlineMs
    repeat: false
    onTriggered: root.finish(root.pendingRequestId, null)
  }
}
