pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

PopupWindow {
  id: root

  default property alias content: popupContent.data

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

  signal dismissed(string section)

  visible: open && parentWindow !== null && anchorItem !== null
  grabFocus: true
  color: "transparent"
  implicitWidth: popupWidth
  implicitHeight: popupHeight

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
    if (!root.anchorItem || !root.parentWindow || !root.parentWindow.contentItem)
      return;

    const position = root.anchorItem.mapToItem(root.parentWindow.contentItem, root.anchorOffsetX, root.anchorOffsetY);
    anchor.rect.x = Math.round(position.x);
    anchor.rect.y = Math.round(position.y);
    anchor.rect.width = Math.max(1, Math.round(root.anchorRectWidth));
    anchor.rect.height = Math.max(1, Math.round(root.anchorRectHeight));
  }
  // qmllint enable missing-type unresolved-type

  Item {
    id: popupContent

    width: root.implicitWidth
    height: root.implicitHeight
    implicitWidth: childrenRect.x + childrenRect.width
    implicitHeight: childrenRect.y + childrenRect.height
    focus: true

    Keys.onEscapePressed: root.dismissed(root.section)
  }
}
