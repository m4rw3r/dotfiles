pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

PopupWindow {
  id: root

  default property alias content: contentHost.data

  property bool open: false
  property string section: ""
  property Item anchorItem: null
  property var parentWindow: null
  property real anchorOffsetX: 0
  property real anchorOffsetY: 0
  property real anchorRectWidth: anchorItem ? anchorItem.width : 1
  property real anchorRectHeight: anchorItem ? anchorItem.height : 1
  property int popupWidth: popupContent.implicitWidth
  property int popupHeight: popupContent.implicitHeight
  property int popupX: 0
  property int popupY: 0

  signal dismissed(string section)

  grabFocus: true
  color: "transparent"
  implicitWidth: parentWindow ? parentWindow.width : popupWidth
  implicitHeight: parentWindow ? parentWindow.height : popupHeight

  function syncPosition() {
    if (!anchorItem || !parentWindow || !parentWindow.contentItem)
      return;

    const position = anchorItem.mapToItem(parentWindow.contentItem, anchorOffsetX, anchorOffsetY);
    popupX = Math.round(position.x);
    popupY = Math.round(position.y);
  }

  function syncVisible() {
    const shouldShow = open && parentWindow !== null && anchorItem !== null;
    if (shouldShow)
      syncPosition();
    visible = shouldShow;
    if (shouldShow)
      Qt.callLater(syncPosition);
  }

  Component.onCompleted: syncVisible()
  onOpenChanged: syncVisible()
  onParentWindowChanged: syncVisible()
  onAnchorItemChanged: syncVisible()

  onVisibleChanged: {
    if (visible) {
      popupContent.forceActiveFocus();
      return;
    }

    if (open)
      dismissed(section);
  }

  // qmllint disable missing-type unresolved-type
  anchor.window: root.parentWindow
  anchor.onAnchoring: {
    root.syncPosition();
    anchor.rect.x = 0;
    anchor.rect.y = 0;
    anchor.rect.width = 1;
    anchor.rect.height = 1;
  }
  // qmllint enable missing-type unresolved-type

  Item {
    anchors.fill: parent

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismissed(root.section)
    }

    Item {
      id: popupContent

      x: root.popupX
      y: root.popupY
      width: root.popupWidth
      height: root.popupHeight
      implicitWidth: contentHost.implicitWidth
      implicitHeight: contentHost.implicitHeight
      focus: true

      MouseArea {
        anchors.fill: parent
      }

      Item {
        id: contentHost

        anchors.fill: parent
        implicitWidth: childrenRect.x + childrenRect.width
        implicitHeight: childrenRect.y + childrenRect.height
      }

      Keys.onEscapePressed: root.dismissed(root.section)
    }
  }
}
