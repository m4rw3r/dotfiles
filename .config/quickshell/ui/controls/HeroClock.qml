import QtQuick
import "../../theme"
import "../primitives" as Ui

Item {
  id: root

  property date currentDateTime: new Date()
  readonly property string timeText: Qt.formatDateTime(currentDateTime, "hh:mm")
  readonly property string dateText: Qt.formatDateTime(currentDateTime, "yyyy-MM-dd")
  readonly property int horizontalInset: Theme.gapXs

  implicitHeight: Theme.controlMd + Theme.gapXs

  function scheduleRefresh() {
    const now = new Date();
    const delayMs = 60000 - (now.getSeconds() * 1000 + now.getMilliseconds());
    refreshTimer.interval = Math.max(1, delayMs);
    refreshTimer.restart();
  }

  function refreshClock() {
    currentDateTime = new Date();
    scheduleRefresh();
  }

  Component.onCompleted: refreshClock()

  Timer {
    id: refreshTimer

    repeat: false
    onTriggered: root.refreshClock()
  }

  Ui.UiText {
    id: timeLabel

    anchors.left: parent.left
    anchors.leftMargin: root.horizontalInset
    anchors.verticalCenter: parent.verticalCenter
    text: root.timeText
    size: "xl"
    tone: "primary"
    font.weight: Font.DemiBold
  }

  Ui.UiText {
    id: dateLabel

    anchors.right: parent.right
    anchors.rightMargin: root.horizontalInset
    anchors.verticalCenter: timeLabel.verticalCenter
    text: root.dateText
    size: "sm"
    tone: "subtle"
    font.weight: Font.DemiBold
  }
}
