pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Item {
  id: root

  property string query: ""
  property int limit: 240
  property var results: []

  function normalizeText(value) {
    return String(value || "").toLowerCase();
  }

  function entryKey(entry) {
    const id = normalizeText(entry.id).trim();
    if (id !== "")
      return `id:${id}`;

    const name = normalizeText(entry.name).trim();
    const genericName = normalizeText(entry.genericName).trim();
    const comment = normalizeText(entry.comment).trim();
    const icon = normalizeText(entry.icon).trim();
    return `meta:${name}|${genericName}|${comment}|${icon}`;
  }

  function refresh() {
    const normalizedQuery = normalizeText(query).trim();
    const entries = DesktopEntries.applications.values;
    const ranked = [];
    const seenEntryKeys = {};

    for (let i = 0; i < entries.length; i += 1) {
      const entry = entries[i];
      if (!entry)
        continue;

      const key = entryKey(entry);
      if (seenEntryKeys[key])
        continue;
      seenEntryKeys[key] = true;

      const name = normalizeText(entry.name);
      const genericName = normalizeText(entry.genericName);
      const comment = normalizeText(entry.comment);
      const id = normalizeText(entry.id);
      const keywords = normalizeText((entry.keywords || []).join(" "));

      let score = 0;
      if (normalizedQuery !== "") {
        if (name.startsWith(normalizedQuery))
          score = 500;
        else if (name.includes(normalizedQuery))
          score = 420;
        else if (genericName.startsWith(normalizedQuery))
          score = 340;
        else if (genericName.includes(normalizedQuery))
          score = 290;
        else if (keywords.includes(normalizedQuery))
          score = 260;
        else if (id.includes(normalizedQuery))
          score = 200;
        else if (comment.includes(normalizedQuery))
          score = 120;
        else
          continue;

        if (id === normalizedQuery)
          score += 300;
      }

      ranked.push({
        entry,
        score,
        sortKey: name !== "" ? name : id
      });
    }

    ranked.sort((a, b) => {
      if (b.score !== a.score)
        return b.score - a.score;
      return a.sortKey.localeCompare(b.sortKey);
    });

    const limited = [];
    const resultLimit = Math.min(ranked.length, limit);
    for (let i = 0; i < resultLimit; i += 1) {
      limited.push(ranked[i].entry);
    }

    results = limited;
  }

  onQueryChanged: refresh()
  onLimitChanged: refresh()
  Component.onCompleted: refresh()

  Connections {
    target: DesktopEntries

    function onApplicationsChanged() {
      root.refresh();
    }
  }
}
