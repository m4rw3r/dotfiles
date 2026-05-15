pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Item {
  id: root

  property string query: ""
  property int limit: 240
  property var results: []
  property var hiddenEntries: []
  property var boostedEntries: []
  property int boostedEntryScore: 180
  property int maxUsageRecords: 160

  PersistentProperties {
    id: persistedUsage

    reloadableId: "launcher-usage-state"

    property string usageJson: "{}"
  }

  function normalizeText(value) {
    const text = String(value || "").toLowerCase();
    if (!text.normalize)
      return text;

    try {
      return text.normalize("NFKD").replace(/[\u0300-\u036f]/g, "");
    } catch (error) {
      return text;
    }
  }

  function searchWords(value) {
    const parts = normalizeText(value).split(/[^a-z0-9]+/);
    const words = [];
    for (let i = 0; i < parts.length; i += 1) {
      if (parts[i] !== "")
        words.push(parts[i]);
    }
    return words;
  }

  function searchAcronym(value) {
    const words = searchWords(value);
    let acronym = "";
    for (let i = 0; i < words.length; i += 1) {
      acronym += words[i].charAt(0);
    }
    return acronym;
  }

  function entryKey(entry) {
    if (!entry)
      return "";

    const id = normalizeText(entry.id).trim();
    if (id !== "")
      return `id:${id}`;

    const name = normalizeText(entry.name).trim();
    const genericName = normalizeText(entry.genericName).trim();
    const comment = normalizeText(entry.comment).trim();
    const icon = normalizeText(entry.icon).trim();
    return `meta:${name}|${genericName}|${comment}|${icon}`;
  }

  function addMatchKey(keys, value) {
    const key = normalizeText(value).trim();
    if (key !== "" && keys.indexOf(key) === -1)
      keys.push(key);
  }

  function entryMatchKeys(entry) {
    const keys = [];
    const id = normalizeText(entry.id).trim();
    addMatchKey(keys, id);
    if (id !== "")
      addMatchKey(keys, `id:${id}`);
    addMatchKey(keys, entryKey(entry));
    addMatchKey(keys, entry.name);
    addMatchKey(keys, entry.genericName);
    addMatchKey(keys, entry.icon);
    return keys;
  }

  function entryMatchesList(entry, list) {
    if (!list)
      return false;

    const curationEntries = Array.isArray(list) ? list : [list];
    if (curationEntries.length === 0)
      return false;

    const keys = entryMatchKeys(entry);
    for (let i = 0; i < curationEntries.length; i += 1) {
      const candidate = normalizeText(curationEntries[i]).trim();
      if (candidate !== "" && keys.indexOf(candidate) !== -1)
        return true;
    }
    return false;
  }

  function entryHidden(entry) {
    return entryMatchesList(entry, hiddenEntries);
  }

  function entryBoosted(entry) {
    return entryMatchesList(entry, boostedEntries);
  }

  function parseQuery(rawQuery) {
    const normalizedQuery = normalizeText(rawQuery).trim();
    if (normalizedQuery.startsWith("!")) {
      return {
        includeHidden: true,
        text: normalizedQuery.substring(1).trim()
      };
    }

    return {
      includeHidden: false,
      text: normalizedQuery
    };
  }

  function isAlphaNumeric(character) {
    if (!character || character.length === 0)
      return false;

    const code = character.charCodeAt(0);
    return (code >= 48 && code <= 57) || (code >= 97 && code <= 122);
  }

  function isWordBoundary(text, index) {
    return index <= 0 || !isAlphaNumeric(text.charAt(index - 1));
  }

  function fuzzySubsequenceScore(candidate, query) {
    const candidateText = normalizeText(candidate);
    const queryText = normalizeText(query);
    if (queryText.length < 2 || candidateText === "" || queryText.length > candidateText.length)
      return -1;

    let position = 0;
    let firstMatch = -1;
    let previousMatch = -1;
    let consecutiveMatches = 0;
    let boundaryMatches = 0;
    let gapPenalty = 0;

    for (let i = 0; i < queryText.length; i += 1) {
      const found = candidateText.indexOf(queryText.charAt(i), position);
      if (found < 0)
        return -1;

      if (firstMatch < 0)
        firstMatch = found;
      if (found === previousMatch + 1)
        consecutiveMatches += 1;
      else if (previousMatch >= 0)
        gapPenalty += found - previousMatch - 1;
      if (isWordBoundary(candidateText, found))
        boundaryMatches += 1;

      previousMatch = found;
      position = found + 1;
    }

    const rawScore = 20 + queryText.length * 6 + consecutiveMatches * 9 + boundaryMatches * 9 - firstMatch * 3 - gapPenalty * 2;
    return Math.max(8, Math.min(45, rawScore));
  }

  function scoreTextField(candidate, query, baseScore) {
    const candidateText = normalizeText(candidate).trim();
    const queryText = normalizeText(query).trim();
    if (candidateText === "" || queryText === "")
      return -1;

    if (candidateText === queryText)
      return baseScore + 120;
    if (candidateText.startsWith(queryText))
      return baseScore + 90;
    if (candidateText.includes(queryText))
      return baseScore + 60;

    const acronym = searchAcronym(candidateText);
    if (acronym !== "" && acronym.startsWith(queryText))
      return baseScore + 50;

    const fuzzyScore = fuzzySubsequenceScore(candidateText, queryText);
    if (fuzzyScore >= 0)
      return baseScore + fuzzyScore;

    return -1;
  }

  function keywordsText(entry) {
    if (!entry.keywords)
      return "";
    if (entry.keywords.join)
      return entry.keywords.join(" ");
    return String(entry.keywords);
  }

  function scoreEntryToken(entry, token) {
    const fields = [
      {
        value: entry.name,
        baseScore: 500
      },
      {
        value: entry.genericName,
        baseScore: 340
      },
      {
        value: keywordsText(entry),
        baseScore: 260
      },
      {
        value: entry.id,
        baseScore: 200
      },
      {
        value: entry.comment,
        baseScore: 120
      }
    ];
    let bestScore = -1;
    for (let i = 0; i < fields.length; i += 1) {
      const score = scoreTextField(fields[i].value, token, fields[i].baseScore);
      if (score > bestScore)
        bestScore = score;
    }
    return bestScore;
  }

  function scoreEntryText(entry, query) {
    const queryText = normalizeText(query).trim();
    if (queryText === "")
      return 0;

    const words = searchWords(queryText);
    if (words.length <= 1)
      return scoreEntryToken(entry, queryText);

    let totalScore = 0;
    for (let i = 0; i < words.length; i += 1) {
      const tokenScore = scoreEntryToken(entry, words[i]);
      if (tokenScore < 0)
        return -1;
      totalScore += tokenScore;
    }
    return totalScore;
  }

  function nonNegativeInteger(value) {
    const number = Number(value);
    if (!isFinite(number) || number < 0)
      return 0;
    return Math.floor(number);
  }

  function cleanUsageRecord(record) {
    if (!record || typeof record !== "object" || Array.isArray(record))
      return null;

    const launchCount = nonNegativeInteger(record.launchCount);
    const lastLaunchedAt = nonNegativeInteger(record.lastLaunchedAt);
    const lastLaunchSerial = nonNegativeInteger(record.lastLaunchSerial);
    if (launchCount === 0 && lastLaunchedAt === 0 && lastLaunchSerial === 0)
      return null;

    return {
      launchCount,
      lastLaunchedAt,
      lastLaunchSerial
    };
  }

  function cleanUsageState(state) {
    const clean = {
      nextSerial: 1,
      entries: {}
    };
    if (!state || typeof state !== "object" || Array.isArray(state))
      return clean;

    clean.nextSerial = Math.max(1, nonNegativeInteger(state.nextSerial));

    const entries = state.entries;
    if (!entries || typeof entries !== "object" || Array.isArray(entries))
      return clean;

    const keys = Object.keys(entries);
    for (let i = 0; i < keys.length; i += 1) {
      const key = String(keys[i] || "");
      const record = cleanUsageRecord(entries[key]);
      if (key !== "" && record)
        clean.entries[key] = record;
    }
    return clean;
  }

  function usageState() {
    try {
      return cleanUsageState(JSON.parse(persistedUsage.usageJson || "{}"));
    } catch (error) {
      return {
        nextSerial: 1,
        entries: {}
      };
    }
  }

  function saveUsageState(state) {
    const clean = cleanUsageState(state);
    const keys = Object.keys(clean.entries);
    keys.sort((a, b) => {
      const recordA = clean.entries[a];
      const recordB = clean.entries[b];
      if (recordB.lastLaunchSerial !== recordA.lastLaunchSerial)
        return recordB.lastLaunchSerial - recordA.lastLaunchSerial;
      if (recordB.lastLaunchedAt !== recordA.lastLaunchedAt)
        return recordB.lastLaunchedAt - recordA.lastLaunchedAt;
      if (recordB.launchCount !== recordA.launchCount)
        return recordB.launchCount - recordA.launchCount;
      return a.localeCompare(b);
    });

    const prunedEntries = {};
    const recordLimit = Math.min(keys.length, Math.max(0, maxUsageRecords));
    for (let i = 0; i < recordLimit; i += 1) {
      const key = keys[i];
      prunedEntries[key] = clean.entries[key];
    }

    persistedUsage.usageJson = JSON.stringify({
      nextSerial: clean.nextSerial,
      entries: prunedEntries
    });
  }

  function usageRecord(entry, state) {
    const source = state || usageState();
    return source.entries[entryKey(entry)] || null;
  }

  function usageScore(entry, queryIsEmpty, state) {
    const record = usageRecord(entry, state);
    if (!record)
      return 0;

    const launchCountScore = Math.min(90, Math.floor(Math.log(record.launchCount + 1) * 36));
    const ageDays = Math.max(0, (Date.now() - record.lastLaunchedAt) / 86400000);
    const recencyScore = record.lastLaunchedAt > 0 ? Math.max(0, Math.floor(140 - ageDays * 18)) : 0;
    const totalScore = launchCountScore + recencyScore;
    return queryIsEmpty ? totalScore : Math.round(totalScore / 20);
  }

  function boostScore(entry, queryIsEmpty) {
    if (!entryBoosted(entry))
      return 0;
    return queryIsEmpty ? boostedEntryScore : Math.round(boostedEntryScore / 2);
  }

  function recordLaunch(entry) {
    if (!entry)
      return;

    const state = usageState();
    const key = entryKey(entry);
    const record = state.entries[key] || {
      launchCount: 0,
      lastLaunchedAt: 0,
      lastLaunchSerial: 0
    };
    const serial = Math.max(1, nonNegativeInteger(state.nextSerial));
    state.entries[key] = {
      launchCount: nonNegativeInteger(record.launchCount) + 1,
      lastLaunchedAt: Date.now(),
      lastLaunchSerial: serial
    };
    state.nextSerial = serial + 1;
    saveUsageState(state);
    refresh();
  }

  function refresh() {
    const parsedQuery = parseQuery(query);
    const effectiveQuery = parsedQuery.text;
    const queryIsEmpty = effectiveQuery === "";
    const entries = DesktopEntries.applications.values;
    const usage = usageState();
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
      if (!parsedQuery.includeHidden && entryHidden(entry))
        continue;

      const textScore = queryIsEmpty ? 0 : scoreEntryText(entry, effectiveQuery);
      if (!queryIsEmpty && textScore < 0)
        continue;

      const usagePoints = usageScore(entry, queryIsEmpty, usage);
      const boostPoints = boostScore(entry, queryIsEmpty);
      const record = usageRecord(entry, usage);
      const name = normalizeText(entry.name).trim();
      const id = normalizeText(entry.id).trim();

      ranked.push({
        entry,
        score: textScore + usagePoints + boostPoints,
        textScore,
        usage: usagePoints,
        boost: boostPoints,
        lastLaunchSerial: record ? record.lastLaunchSerial : 0,
        sortKey: name !== "" ? name : (id !== "" ? id : key)
      });
    }

    ranked.sort((a, b) => {
      if (b.score !== a.score)
        return b.score - a.score;
      if (b.textScore !== a.textScore)
        return b.textScore - a.textScore;
      if (b.boost !== a.boost)
        return b.boost - a.boost;
      if (b.usage !== a.usage)
        return b.usage - a.usage;
      if (b.lastLaunchSerial !== a.lastLaunchSerial)
        return b.lastLaunchSerial - a.lastLaunchSerial;
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
  onHiddenEntriesChanged: refresh()
  onBoostedEntriesChanged: refresh()
  Component.onCompleted: refresh()

  Connections {
    target: DesktopEntries

    function onApplicationsChanged() {
      root.refresh();
    }
  }
}
