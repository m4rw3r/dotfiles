pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.SystemTray

Item {
  id: root

  property string mode: "hidden"
  property bool userPinned: false
  property bool peekForced: false
  property int attentionCount: 0
  property int activeCount: 0
  property int passiveCount: 0
  property int itemCount: 0
  property int revision: 0
  readonly property bool hasAttention: attentionCount > 0
  readonly property bool hasItems: itemCount > 0

  function refresh() {
    let nextAttention = 0;
    let nextActive = 0;
    let nextPassive = 0;
    let nextCount = 0;

    // qmllint disable missing-property
    const values = SystemTray.items.values;
    if (values) {
      for (let i = 0; i < values.length; i += 1) {
        const item = values[i];
        if (!item)
          continue;
        nextCount += 1;
        if (item.status === Status.NeedsAttention)
          nextAttention += 1;
        else if (item.status === Status.Active)
          nextActive += 1;
        else if (item.status === Status.Passive)
          nextPassive += 1;
      }
    }
    // qmllint enable missing-property

    itemCount = nextCount;
    attentionCount = nextAttention;
    activeCount = nextActive;
    passiveCount = nextPassive;
    revision += 1;
  }

  function collapseToPeekOrHidden() {
    userPinned = false;
    mode = (peekForced || hasAttention) ? "peek" : "hidden";
  }

  function openFromPeek() {
    peekForced = false;
    userPinned = true;
    mode = "expanded";
  }

  function openFromControlCenter() {
    peekForced = false;
    userPinned = false;
    mode = "expanded";
  }

  function toggleFromControlCenter() {
    if (mode === "hidden" || mode === "peek") {
      openFromControlCenter();
      return;
    }

    close();
  }

  function forcePeek() {
    peekForced = true;
    userPinned = false;
    mode = "peek";
  }

  function close() {
    peekForced = false;
    userPinned = false;
    mode = hasAttention ? "peek" : "hidden";
  }

  function open() {
    peekForced = false;
    userPinned = true;
    mode = "expanded";
  }

  function toggle() {
    if (mode === "expanded")
      close();
    else
      open();
  }

  Component.onCompleted: refresh()

  onHasAttentionChanged: {
    if (hasAttention) {
      if (mode === "hidden")
        mode = "peek";
      return;
    }

    if (mode === "peek" && !peekForced)
      mode = "hidden";
  }

  Instantiator {
    id: tracker

    model: SystemTray.items

    delegate: Item {
      id: trackedItem

      required property var modelData
      visible: false
      width: 0
      height: 0

      Connections {
        target: trackedItem.modelData
        ignoreUnknownSignals: true

        function onStatusChanged() {
          Qt.callLater(root.refresh);
        }

        function onReady() {
          Qt.callLater(root.refresh);
        }
      }
    }

    onObjectAdded: Qt.callLater(root.refresh)
    onObjectRemoved: Qt.callLater(root.refresh)
  }
}
