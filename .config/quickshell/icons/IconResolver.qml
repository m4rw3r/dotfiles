pragma Singleton

import QtQuick
import Quickshell

Singleton {
  id: root

  readonly property var glyphAliases: ({
    "restart": "rotate-cw",
    "logout": "log-out",
    "speaker": "volume-2",
    "speaker-muted": "volume-x",
    "battery": "battery-medium"
  })

  readonly property var iconAliases: ({
    "application-x-executable": { type: "glyph", value: "app-window" },
    "org.gnome.terminal": { type: "glyph", value: "terminal" },
    "org.gnome.terminal.desktop": { type: "glyph", value: "terminal" },
    "alacritty": { type: "glyph", value: "terminal" },
    "utilities-system-monitor": { type: "glyph", value: "monitor" },
    "btop": { type: "glyph", value: "monitor" },
    "preferences-system-network": { type: "glyph", value: "network" },
    "network-wired": { type: "glyph", value: "network" },
    "printer": { type: "glyph", value: "printer" },
    "dropbox": { type: "glyph", value: "cloud" },
    "dropboxstatus-idle": { type: "glyph", value: "cloud" },
    "dropboxstatus-logo": { type: "glyph", value: "cloud" },
    "dropboxstatus-blank": { type: "glyph", value: "cloud" },
    "dropboxstatus-busy": { type: "glyph", value: "cloud-sync" },
    "dropboxstatus-busy2": { type: "glyph", value: "cloud-sync" },
    "dropboxstatus-x": { type: "glyph", value: "cloud-off" }
  })

  readonly property var aliasOnlyKeys: ({
    "dropbox": true,
    "dropboxstatus-idle": true,
    "dropboxstatus-logo": true,
    "dropboxstatus-blank": true,
    "dropboxstatus-busy": true,
    "dropboxstatus-busy2": true,
    "dropboxstatus-x": true,
    "btop": true
  })

  function stringValue(value) {
    return String(value || "").trim();
  }

  function stripFileScheme(value) {
    const text = stringValue(value);
    return text.startsWith("file://") ? text.slice(7) : text;
  }

  function basename(value) {
    const text = stripFileScheme(value);
    const slashIndex = text.lastIndexOf("/");
    return slashIndex >= 0 ? text.slice(slashIndex + 1) : text;
  }

  function stripQuery(value) {
    const text = stringValue(value);
    const queryIndex = text.indexOf("?");
    return queryIndex >= 0 ? text.slice(0, queryIndex) : text;
  }

  function stripExtension(value) {
    const text = stringValue(value);
    const dotIndex = text.lastIndexOf(".");
    return dotIndex > 0 ? text.slice(0, dotIndex) : text;
  }

  function parseIconProviderSource(value) {
    const text = stringValue(value);
    if (!text.startsWith("image://icon/")) return { name: "", query: "" };

    const request = text.slice("image://icon/".length);
    const queryIndex = request.indexOf("?");
    return {
      name: queryIndex >= 0 ? request.slice(0, queryIndex) : request,
      query: queryIndex >= 0 ? request.slice(queryIndex + 1) : ""
    };
  }

  function canonicalName(value) {
    const text = stringValue(value);
    if (text === "") return "";

    if (text.startsWith("image://icon/")) {
      const parsed = parseIconProviderSource(text);
      return canonicalName(parsed.name);
    }

    if (text.startsWith("image://") || text.startsWith("qrc:/") || text.startsWith("data:")) return "";

    const withoutQuery = stripQuery(text);
    const simpleName = withoutQuery.indexOf("/") >= 0 || withoutQuery.startsWith("file://")
      ? basename(withoutQuery)
      : withoutQuery;

    return stripExtension(simpleName).toLowerCase();
  }

  function pushUnique(list, seen, value) {
    const text = stringValue(value);
    if (text === "" || seen[text]) return;
    seen[text] = true;
    list.push(text);
  }

  function rawThemeName(value) {
    const text = stringValue(value);
    if (text === "") return "";

    if (text.startsWith("image://icon/")) {
      const parsed = parseIconProviderSource(text);
      return stringValue(parsed.name);
    }

    if (text.startsWith("image://") || text.startsWith("file://") || text.startsWith("qrc:/") || text.startsWith("data:") || text.startsWith("/")) {
      return "";
    }

    return stripQuery(text);
  }

  function rawThemeCandidates(icon, desktopEntry, appName) {
    const candidates = [];
    const seen = {};
    const values = [icon, desktopEntry, appName];

    for (let index = 0; index < values.length; index += 1) {
      const value = values[index];
      const candidate = rawThemeName(value);
      const normalized = canonicalName(value);

      if (candidate !== "") {
        pushUnique(candidates, seen, candidate);
        pushUnique(candidates, seen, stripExtension(candidate));
      }

      pushUnique(candidates, seen, normalized);
    }

    return candidates;
  }

  function uniqueCandidateKeys(icon, desktopEntry, appName) {
    const keys = [];
    const seen = {};
    const values = [icon, desktopEntry, appName];

    for (let index = 0; index < values.length; index += 1) {
      const key = canonicalName(values[index]);
      if (key === "" || seen[key]) continue;
      seen[key] = true;
      keys.push(key);
    }

    return keys;
  }

  function isExternalSource(value) {
    const text = stringValue(value);
    return text.startsWith("image://")
      || text.startsWith("file://")
      || text.startsWith("qrc:/")
      || text.startsWith("data:")
      || text.startsWith("/")
      || text.indexOf("://") >= 0
      || text.indexOf("?path=") >= 0;
  }

  function resolveGlyphName(name) {
    const rawName = stringValue(name);
    if (rawName === "" || isExternalSource(rawName) || rawName.indexOf("/") >= 0) return "";
    return glyphAliases[rawName] !== undefined ? glyphAliases[rawName] : rawName;
  }

  function glyphSource(name) {
    const glyphName = resolveGlyphName(name);
    return glyphName === "" ? "" : Qt.resolvedUrl(`${glyphName}.svg`);
  }

  function applyAlias(alias) {
    if (!alias) return "";

    if (alias.type === "glyph") return glyphSource(alias.value);
    if (alias.type === "theme") return themeIconSource(alias.value);
    if (alias.type === "source") return stringValue(alias.value);

    return "";
  }

  function resolveAlias(icon, desktopEntry, appName) {
    const keys = uniqueCandidateKeys(icon, desktopEntry, appName);

    for (let index = 0; index < keys.length; index += 1) {
      const alias = iconAliases[keys[index]];
      const resolved = applyAlias(alias);
      if (resolved !== "") return resolved;
    }

    return "";
  }

  function resolveAliasOnly(icon, desktopEntry, appName) {
    const keys = uniqueCandidateKeys(icon, desktopEntry, appName);

    for (let index = 0; index < keys.length; index += 1) {
      const key = keys[index];
      if (!aliasOnlyKeys[key]) continue;

      const alias = iconAliases[key];
      const resolved = applyAlias(alias);
      if (resolved !== "") return resolved;
    }

    return "";
  }

  function passthroughSource(icon) {
    const text = stringValue(icon);
    if (text === "" || text.startsWith("image://icon/")) return "";
    if (text.startsWith("image://") || text.startsWith("file://") || text.startsWith("qrc:/") || text.startsWith("data:")) return text;
    if (text.startsWith("/")) return `file://${text}`;
    return "";
  }

  function themeIconSource(icon) {
    const iconName = stringValue(icon);
    if (iconName === "") return "";
    return String(Quickshell.iconPath(iconName, true) || "");
  }

  function resolveTheme(icon, desktopEntry, appName) {
    const candidates = rawThemeCandidates(icon, desktopEntry, appName);

    for (let index = 0; index < candidates.length; index += 1) {
      const resolved = themeIconSource(candidates[index]);
      if (resolved !== "") return resolved;
    }

    return "";
  }

  function resolve(icon, options) {
    const opts = options || {};
    const directSource = passthroughSource(icon);
    if (directSource !== "") return directSource;

    const themedIcon = resolveTheme(icon, opts.desktopEntry, opts.appName);
    if (themedIcon !== "") return themedIcon;

    const aliasOnlySource = resolveAliasOnly(icon, opts.desktopEntry, opts.appName);
    if (aliasOnlySource !== "") return aliasOnlySource;

    const directAlias = resolveAlias(icon, opts.desktopEntry, opts.appName);
    if (directAlias !== "") return directAlias;

    const fallbackSource = resolveAlias("", opts.desktopEntry, opts.appName);
    if (fallbackSource !== "") return fallbackSource;

    const fallback = stringValue(opts.fallback);
    if (fallback !== "" && fallback !== stringValue(icon)) {
      const fallbackDirect = passthroughSource(fallback);
      if (fallbackDirect !== "") return fallbackDirect;

      const fallbackThemed = resolveTheme(fallback, "", "");
      if (fallbackThemed !== "") return fallbackThemed;

      const fallbackAlias = resolveAlias(fallback, "", "");
      if (fallbackAlias !== "") return fallbackAlias;
    }

    return "";
  }
}
