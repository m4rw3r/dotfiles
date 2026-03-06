pragma Singleton

import QtQuick
import Quickshell

Singleton {
  id: root

  readonly property var palettes: ({
    graphite: {
      scrim: "#8211181f",
      panel: "#20262f",
      panelRaised: "#273241",
      field: "#2b3745",
      fieldPressed: "#334153",
      border: "#334457",
      text: "#edf3f8",
      textMuted: "#c4d7e5",
      textSubtle: "#91a5b6",
      textOnAccent: "#ffffff",
      accent: "#5f91bf",
      accentStrong: "#7badde"
    },
    dawn: {
      scrim: "#6f12151a",
      panel: "#f2ece4",
      panelRaised: "#ffffff",
      field: "#e9dfd2",
      fieldPressed: "#deceb9",
      border: "#c8b39a",
      text: "#2f2a24",
      textMuted: "#55493c",
      textSubtle: "#716152",
      textOnAccent: "#ffffff",
      accent: "#c06f39",
      accentStrong: "#d48a56"
    }
  })

  PersistentProperties {
    id: persisted
    reloadableId: "theme-state"

    property string selectedTheme: "graphite"
  }

  readonly property var themeNames: Object.keys(palettes)
  readonly property string current: persisted.selectedTheme
  readonly property var palette: palettes[current] !== undefined ? palettes[current] : palettes.graphite

  readonly property color scrim: palette.scrim
  readonly property color panel: palette.panel
  readonly property color panelRaised: palette.panelRaised
  readonly property color field: palette.field
  readonly property color fieldPressed: palette.fieldPressed
  readonly property color border: palette.border
  readonly property color text: palette.text
  readonly property color textMuted: palette.textMuted
  readonly property color textSubtle: palette.textSubtle
  readonly property color textOnAccent: palette.textOnAccent
  readonly property color accent: palette.accent
  readonly property color accentStrong: palette.accentStrong

  readonly property int radiusSm: 10
  readonly property int radiusMd: 16
  readonly property int radiusLg: 24

  readonly property int textXs: 13
  readonly property int textSm: 14
  readonly property int textMd: 17
  readonly property int textLg: 22
  readonly property int textXl: 24

  readonly property int iconSm: 42
  readonly property int iconMd: 46

  readonly property int motionFast: 120
  readonly property int motionBase: 170
  readonly property int motionSlow: 220

  readonly property string fontFamily: "Noto Sans"

  readonly property color selection: accent

  function setTheme(name) {
    if (palettes[name] === undefined) return false;
    if (persisted.selectedTheme === name) return true;
    persisted.selectedTheme = name;
    return true;
  }

  function toggleTheme() {
    const names = themeNames;
    if (names.length === 0) return "";

    const currentIndex = names.indexOf(persisted.selectedTheme);
    const nextIndex = currentIndex < 0 ? 0 : (currentIndex + 1) % names.length;
    persisted.selectedTheme = names[nextIndex];
    return persisted.selectedTheme;
  }
}
