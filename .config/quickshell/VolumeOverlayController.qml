pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire

Item {
  id: root

  property bool overlayBlocked: false
  property bool active: false
  property bool initialized: false
  property real value: 0
  property bool muted: false
  readonly property var trackedSink: Pipewire.defaultAudioSink
  readonly property var trackedAudio: trackedSink && trackedSink.audio ? trackedSink.audio : null
  readonly property bool trackedReady: Pipewire.ready && !!trackedSink && trackedSink.ready && !!trackedAudio
  readonly property real trackedValue: trackedReady ? normalizeVolumeValue(trackedAudio.volume) : 0
  readonly property bool trackedMuted: trackedReady ? !!trackedAudio.muted : false

  function normalizeVolumeValue(nextValue) {
    return Math.max(0, Math.min(1, Number(nextValue) || 0));
  }

  function syncState(shouldReveal) {
    if (!trackedReady) {
      if (!trackedSink)
        initialized = false;
      return;
    }

    const nextVolume = trackedValue;
    const nextMuted = trackedMuted;
    const volumeChanged = !initialized || Math.abs(nextVolume - value) > 0.0005 || nextMuted !== muted;

    value = nextVolume;
    muted = nextMuted;

    if (!initialized) {
      initialized = true;
      return;
    }

    if (shouldReveal && volumeChanged && !overlayBlocked) {
      active = true;
      hideTimer.restart();
    }
  }

  function reveal() {
    syncState(false);
    if (!trackedReady || overlayBlocked)
      return;
    active = true;
    hideTimer.restart();
  }

  function flash() {
    flashTimer.restart();
  }

  Component.onCompleted: syncState(false)

  onOverlayBlockedChanged: {
    if (!overlayBlocked)
      return;
    active = false;
    hideTimer.stop();
  }

  onTrackedSinkChanged: {
    initialized = false;
    syncState(false);
  }

  onTrackedReadyChanged: syncState(false)

  onTrackedValueChanged: syncState(true)

  onTrackedMutedChanged: syncState(true)

  onTrackedAudioChanged: {
    initialized = false;
    if (!trackedAudio) {
      active = false;
      hideTimer.stop();
      return;
    }

    syncState(false);
  }

  PwObjectTracker {
    objects: [root.trackedSink]
  }

  Timer {
    id: hideTimer
    interval: 1100
    repeat: false
    onTriggered: root.active = false
  }

  Timer {
    id: flashTimer
    interval: 60
    repeat: false
    onTriggered: root.reveal()
  }
}
