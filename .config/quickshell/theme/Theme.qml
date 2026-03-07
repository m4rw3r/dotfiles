pragma Singleton

import QtQuick
import Quickshell

Singleton {
  id: root

  readonly property var palettes: ({
    graphite: {
      scrim: "#8210141b",
      panel: "#1c1d20",
      panelOverlay: "#202226",
      panelRaised: "#43454b",
      submenu: "#494c53",
      field: "#2a2d32",
      fieldAlt: "#343840",
      fieldPressed: "#40454e",
      border: "#454a55",
      divider: "#585e6b",
      text: "#f3f5f7",
      textMuted: "#d8dbe0",
      textSubtle: "#a4aab3",
      iconSecondary: "#d0d5dd",
      textOnAccent: "#ffffff",
      accent: "#3b7de1",
      accentStrong: "#6b9eeb",
      toggleOn: "#3b7de1",
      toggleOnStrong: "#6b9eeb",
      toggleOff: "#31343a",
      sliderTrack: "#676b74",
      sliderFill: "#6b9eeb",
      chip: "#2c3036"
    },
    dawn: {
      scrim: "#6f12151a",
      panel: "#f1ebe3",
      panelOverlay: "#ece4da",
      panelRaised: "#ffffff",
      submenu: "#faf6f1",
      field: "#e8ddd0",
      fieldAlt: "#dfd0bf",
      fieldPressed: "#d4c0aa",
      border: "#c8b39a",
      divider: "#b8a48f",
      text: "#2f2a24",
      textMuted: "#55493c",
      textSubtle: "#716152",
      iconSecondary: "#55493c",
      textOnAccent: "#ffffff",
      accent: "#c06f39",
      accentStrong: "#d48a56",
      toggleOn: "#c06f39",
      toggleOnStrong: "#d48a56",
      toggleOff: "#d2c1ae",
      sliderTrack: "#bba996",
      sliderFill: "#d48a56",
      chip: "#dfd0bf"
    }
  })

  PersistentProperties {
    id: persisted
    reloadableId: "theme-state"

    property string selectedTheme: "graphite"
  }

  readonly property var themeNames: Object.keys(palettes)
  readonly property string defaultTheme: palettes.graphite !== undefined
    ? "graphite"
    : (themeNames.length > 0 ? themeNames[0] : "")
  readonly property string current: normalizeThemeName(persisted.selectedTheme)
  readonly property var palette: palettes[current] !== undefined ? palettes[current] : palettes.graphite

  readonly property color scrim: palette.scrim
  readonly property color panel: palette.panel
  readonly property color panelOverlay: palette.panelOverlay
  readonly property color panelRaised: palette.panelRaised
  readonly property color submenu: palette.submenu
  readonly property color field: palette.field
  readonly property color fieldAlt: palette.fieldAlt
  readonly property color fieldPressed: palette.fieldPressed
  readonly property color border: palette.border
  readonly property color divider: palette.divider
  readonly property color text: palette.text
  readonly property color textMuted: palette.textMuted
  readonly property color textSubtle: palette.textSubtle
  readonly property color iconSecondary: palette.iconSecondary
  readonly property color textOnAccent: palette.textOnAccent
  readonly property color accent: palette.accent
  readonly property color accentStrong: palette.accentStrong
  readonly property color toggleOn: palette.toggleOn
  readonly property color toggleOnStrong: palette.toggleOnStrong
  readonly property color toggleOff: palette.toggleOff
  readonly property color sliderTrack: palette.sliderTrack
  readonly property color sliderFill: palette.sliderFill
  readonly property color chip: palette.chip

  readonly property int radiusSm: 12
  readonly property int radiusMd: 18
  readonly property int radiusLg: 22

  readonly property int textXs: 12
  readonly property int textSm: 14
  readonly property int textMd: 16
  readonly property int textLg: 22
  readonly property int textXl: 24

  readonly property int iconSm: 42
  readonly property int iconMd: 46
  readonly property int controlAccessorySlot: 32

  readonly property int motionFast: 120
  readonly property int motionBase: 170
  readonly property int motionSlow: 220

  readonly property string fontFamily: "Cantarell"

  readonly property color selection: accent

  Component.onCompleted: sanitizePersistedTheme()

  function normalizeThemeName(name) {
    const normalizedName = String(name || "");
    return palettes[normalizedName] !== undefined ? normalizedName : defaultTheme;
  }

  function sanitizePersistedTheme() {
    const normalizedName = normalizeThemeName(persisted.selectedTheme);
    if (persisted.selectedTheme !== normalizedName) persisted.selectedTheme = normalizedName;
    return normalizedName;
  }

  function setTheme(name) {
    const normalizedName = normalizeThemeName(name);
    if (normalizedName === "") return false;
    if (persisted.selectedTheme === normalizedName) return true;
    persisted.selectedTheme = normalizedName;
    return true;
  }

  function toggleTheme() {
    const names = themeNames;
    if (names.length === 0) return "";

    const currentIndex = names.indexOf(current);
    const nextIndex = currentIndex < 0 ? 0 : (currentIndex + 1) % names.length;
    persisted.selectedTheme = names[nextIndex];
    return persisted.selectedTheme;
  }
}
