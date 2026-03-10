import QtQuick
import "../../theme"

Rectangle {
  id: root

  property int horizontalInset: 18

  width: parent ? Math.max(0, parent.width - horizontalInset * 2) : 0
  height: Theme.stroke
  radius: height / 2
  x: parent ? Math.floor((parent.width - width) / 2) : 0
  color: Theme.divider
  opacity: 0.72
}
