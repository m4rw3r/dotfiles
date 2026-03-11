import QtQuick
import Quickshell.Widgets
import "../../icons" as Icons

IconImage {
  id: root

  property string icon: ""
  property string desktopEntry: ""
  property string appName: ""
  property string fallback: ""

  readonly property string resolvedSource: Icons.IconResolver.resolve(icon, {
    desktopEntry: desktopEntry,
    appName: appName,
    fallback: fallback
  })

  source: resolvedSource
}
