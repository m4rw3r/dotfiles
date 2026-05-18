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
    property bool dynamicAccentEnabled: false
    property string dynamicAccentSource: ""
  }

  readonly property var themeNames: Object.keys(palettes)
  readonly property string defaultTheme: palettes.graphite !== undefined ? "graphite" : (themeNames.length > 0 ? themeNames[0] : "")
  readonly property string current: normalizeThemeName(persisted.selectedTheme)
  readonly property var palette: palettes[current] !== undefined ? palettes[current] : palettes.graphite
  readonly property bool dynamicAccentEnabled: persisted.dynamicAccentEnabled
  readonly property string dynamicAccentSource: persisted.dynamicAccentSource
  readonly property var dynamicAccentCandidate: chooseDynamicAccentCandidate()
  readonly property bool dynamicAccentActive: dynamicAccentCandidate !== null && dynamicAccentCandidate !== undefined

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
  readonly property color accent: dynamicAccentActive ? dynamicAccentCandidate : palette.accent
  readonly property color accentStrong: dynamicAccentActive ? accentVariant(accent) : palette.accentStrong
  readonly property color toggleOn: dynamicAccentActive ? accent : palette.toggleOn
  readonly property color toggleOnStrong: dynamicAccentActive ? accentStrong : palette.toggleOnStrong
  readonly property color toggleOff: palette.toggleOff
  readonly property color sliderTrack: palette.sliderTrack
  readonly property color sliderFill: dynamicAccentActive ? accentStrong : palette.sliderFill
  readonly property color chip: palette.chip
  readonly property color panelOverlayBlur: withAlpha(panelOverlay, current === "dawn" ? 0.92 : 0.86)
  readonly property color submenuBlur: withAlpha(submenu, current === "dawn" ? 0.94 : 0.88)
  readonly property color fieldBlur: withAlpha(field, current === "dawn" ? 0.93 : 0.86)

  readonly property color borderSubtle: Qt.rgba(1, 1, 1, 0.08)
  readonly property color borderNormal: Qt.rgba(1, 1, 1, 0.1)
  readonly property color borderStrong: Qt.rgba(1, 1, 1, 0.12)
  readonly property color borderAccent: Qt.rgba(1, 1, 1, 0.16)
  readonly property color overlayPressed: Qt.rgba(1, 1, 1, 0.035)
  readonly property color overlayActive: Qt.rgba(1, 1, 1, 0.06)

  readonly property int stroke: 1
  readonly property int nudge: 4
  readonly property int gapXs: 8
  readonly property int gapSm: 12
  readonly property int gapMd: 16
  readonly property int gapLg: 24

  readonly property int insetSm: gapSm
  readonly property int insetMd: gapMd
  readonly property int insetLg: gapLg

  readonly property int radiusSm: 12
  readonly property int radiusMd: 16
  readonly property int radiusLg: 24

  readonly property int textXs: 10
  readonly property int textSm: 12
  readonly property int textMd: 14
  readonly property int textLg: 18
  readonly property int textXl: 22

  readonly property int iconGlyphSm: 16
  readonly property int iconGlyphMd: 24

  readonly property int controlSm: 36
  readonly property int controlMd: 44
  readonly property int tileHeight: controlMd
  readonly property int tileSplitWidth: controlSm
  readonly property int controlAccessorySlot: controlSm

  readonly property int popoverWidthSm: 192
  readonly property int popoverWidthMd: 224
  readonly property int overlayMargin: gapMd

  readonly property int launcherTileIconSm: controlSm
  readonly property int launcherTileIconMd: controlMd

  // Backwards-compatibility aliases while measurements are migrated.
  readonly property int iconSm: launcherTileIconSm
  readonly property int iconMd: launcherTileIconMd

  readonly property int motionFast: 120
  readonly property int motionBase: 170
  readonly property int motionSlow: 220

  readonly property string fontFamily: "Cantarell"

  readonly property color selection: accent

  ColorQuantizer {
    id: accentQuantizer

    source: root.dynamicAccentEnabled ? root.dynamicAccentSourceUrl() : ""
    depth: 3
    rescaleSize: 64
  }

  Component.onCompleted: sanitizePersistedTheme()

  function withAlpha(color, alpha) {
    return Qt.rgba(color.r, color.g, color.b, alpha);
  }

  function mixColors(color, target, amount) {
    return Qt.rgba(color.r + (target.r - color.r) * amount, color.g + (target.g - color.g) * amount, color.b + (target.b - color.b) * amount, color.a);
  }

  function colorBrightness(color) {
    return color.r * 0.299 + color.g * 0.587 + color.b * 0.114;
  }

  function colorSaturation(color) {
    const maxChannel = Math.max(color.r, color.g, color.b);
    const minChannel = Math.min(color.r, color.g, color.b);
    return maxChannel <= 0 ? 0 : (maxChannel - minChannel) / maxChannel;
  }

  function accentVariant(color) {
    const brightness = colorBrightness(color);
    const target = brightness > 0.56 ? Qt.rgba(0, 0, 0, 1) : Qt.rgba(1, 1, 1, 1);
    return mixColors(color, target, brightness > 0.56 ? 0.12 : 0.22);
  }

  function usableAccentColor(color) {
    if (!color)
      return false;

    const brightness = colorBrightness(color);
    return colorSaturation(color) >= 0.18 && brightness >= 0.22 && brightness <= 0.72;
  }

  function chooseDynamicAccentCandidate() {
    if (!persisted.dynamicAccentEnabled || persisted.dynamicAccentSource === "")
      return null;

    const colors = accentQuantizer.colors;
    if (!colors || colors.length === 0)
      return null;

    for (let index = 0; index < colors.length; index += 1) {
      const color = colors[index];
      if (usableAccentColor(color))
        return color;
    }

    return null;
  }

  function dynamicAccentSourceUrl() {
    const source = String(persisted.dynamicAccentSource || "").trim();
    if (source === "")
      return "";
    if (/^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(source))
      return source;
    if (source[0] === "/")
      return `file://${source}`;
    return source;
  }

  function normalizeThemeName(name) {
    const normalizedName = String(name || "");
    return palettes[normalizedName] !== undefined ? normalizedName : defaultTheme;
  }

  function sanitizePersistedTheme() {
    const normalizedName = normalizeThemeName(persisted.selectedTheme);
    if (persisted.selectedTheme !== normalizedName)
      persisted.selectedTheme = normalizedName;
    return normalizedName;
  }

  function setTheme(name) {
    const normalizedName = normalizeThemeName(name);
    if (normalizedName === "")
      return false;
    if (persisted.selectedTheme === normalizedName)
      return true;
    persisted.selectedTheme = normalizedName;
    return true;
  }

  function toggleTheme() {
    const names = themeNames;
    if (names.length === 0)
      return "";

    const currentIndex = names.indexOf(current);
    const nextIndex = currentIndex < 0 ? 0 : (currentIndex + 1) % names.length;
    persisted.selectedTheme = names[nextIndex];
    return persisted.selectedTheme;
  }

  function setDynamicAccentEnabled(enabled) {
    const value = String(enabled).toLowerCase();
    persisted.dynamicAccentEnabled = enabled === true || value === "true" || value === "1" || value === "yes" || value === "on";
    return persisted.dynamicAccentEnabled;
  }

  function setDynamicAccentSource(path) {
    persisted.dynamicAccentSource = String(path || "").trim();
    return persisted.dynamicAccentSource;
  }

  function clearDynamicAccentSource() {
    return setDynamicAccentSource("");
  }
}
