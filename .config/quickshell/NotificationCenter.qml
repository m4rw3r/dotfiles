pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Notifications

Item {
  id: root

  property var entries: []
  property var toastUids: []
  property int revision: 0
  property int nextUid: 1
  property int maxToasts: 3
  readonly property var groupedEntries: buildGroups(entries)
  readonly property int unreadCount: countUnread(entries)
  readonly property int criticalUnreadCount: countCriticalUnread(entries)
  readonly property bool hasUnread: unreadCount > 0
  readonly property bool hasCriticalUnread: criticalUnreadCount > 0
  readonly property var latestEntry: entries.length > 0 ? entries[0] : null
  readonly property var latestUnreadEntry: firstUnread(entries)
  readonly property var footerEntry: hasUnread ? latestUnreadEntry : latestEntry
  readonly property int trackedCount: entries.length
  readonly property real defaultToastTimeoutMs: 6500

  function cleanText(text) {
    return String(text || "").replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
  }

  function appLabel(entry) {
    if (!entry) return "Notifications";
    if (entry.appName !== "") return entry.appName;
    if (entry.desktopEntry !== "") return entry.desktopEntry;
    return "Notification";
  }

  function summaryLabel(entry) {
    if (!entry) return "No notifications";
    if (entry.summary !== "") return entry.summary;
    if (entry.body !== "") return entry.body;
    return appLabel(entry);
  }

  function bodyLabel(entry) {
    if (!entry) return "";
    if (entry.body === "" || entry.body === entry.summary) return "";
    return entry.body;
  }

  function ageLabel(entry) {
    if (!entry || !entry.receivedAt) return "";

    const elapsedSeconds = Math.max(1, Math.floor((Date.now() - entry.receivedAt) / 1000));
    if (elapsedSeconds < 60) return `${elapsedSeconds}s`;

    const elapsedMinutes = Math.floor(elapsedSeconds / 60);
    if (elapsedMinutes < 60) return `${elapsedMinutes}m`;

    const elapsedHours = Math.floor(elapsedMinutes / 60);
    if (elapsedHours < 24) return `${elapsedHours}h`;

    return `${Math.floor(elapsedHours / 24)}d`;
  }

  function unreadCountLabel() {
    if (unreadCount <= 0) return "";
    if (unreadCount === 1) return "1 unread";
    return `${unreadCount} unread`;
  }

  function trackedCountLabel() {
    if (trackedCount <= 0) return "";
    if (trackedCount === 1) return "1 item";
    return `${trackedCount} items`;
  }

  function sourceKey(entry) {
    if (!entry) return "notifications";

    const desktopEntry = cleanText(entry.desktopEntry);
    if (desktopEntry !== "") return `desktop:${desktopEntry}`;

    const appName = cleanText(entry.appName);
    if (appName !== "") return `app:${appName}`;

    return `fallback:${cleanText(entry.appIcon)}:${cleanText(entry.summary)}`;
  }

  function buildGroups(list) {
    const groups = [];
    const indexByKey = {};

    for (let index = 0; index < list.length; index += 1) {
      const entry = list[index];
      const key = sourceKey(entry);
      let groupIndex = indexByKey[key];

      if (groupIndex === undefined) {
        groupIndex = groups.length;
        indexByKey[key] = groupIndex;
        groups.push({
          key: key,
          latestEntry: entry,
          entries: [],
          entryCount: 0,
          unreadCount: 0,
          criticalUnreadCount: 0,
          liveCount: 0,
          appName: appLabel(entry),
          appIcon: entry ? String(entry.appIcon || "") : ""
        });
      }

      const group = groups[groupIndex];
      group.entries.push(entry);
      group.entryCount += 1;
      if (entry.unread) group.unreadCount += 1;
      if (entry.unread && entry.urgency === NotificationUrgency.Critical) group.criticalUnreadCount += 1;
      if (entry.live) group.liveCount += 1;
    }

    return groups;
  }

  function primaryAction(entry) {
    if (!entry || !entry.notification || !entry.live) return null;
    if (!entry.notification.actions || entry.notification.actions.length <= 0) return null;
    return entry.notification.actions[0];
  }

  function primaryActionLabel(entry) {
    const action = primaryAction(entry);
    if (!action) return "";

    const text = cleanText(action.text);
    if (text === "") return "Open";
    return text.length > 14 ? "Open" : text;
  }

  function toastTimeoutMs(entry) {
    if (!entry || entry.urgency === NotificationUrgency.Critical) return 0;

    const timeoutMs = Math.round(Number(entry.expireTimeout || 0) * 1000);
    if (timeoutMs > 0) return Math.max(3500, Math.min(12000, timeoutMs));
    return defaultToastTimeoutMs;
  }

  function toastRemainingMs(entry) {
    if (!entry || !entry.toastExpiresAt) return 0;
    return Math.max(0, entry.toastExpiresAt - Date.now());
  }

  function entryForUid(uid) {
    for (let index = 0; index < entries.length; index += 1) {
      if (entries[index].uid === uid) return entries[index];
    }

    return null;
  }

  function setEntries(nextEntries) {
    entries = nextEntries;
    revision += 1;
  }

  function setToastUids(nextToastUids) {
    toastUids = nextToastUids;
    revision += 1;
  }

  function countUnread(list) {
    let count = 0;

    for (let index = 0; index < list.length; index += 1) {
      if (list[index].unread) count += 1;
    }

    return count;
  }

  function countCriticalUnread(list) {
    let count = 0;

    for (let index = 0; index < list.length; index += 1) {
      const entry = list[index];
      if (entry.unread && entry.urgency === NotificationUrgency.Critical) count += 1;
    }

    return count;
  }

  function firstUnread(list) {
    for (let index = 0; index < list.length; index += 1) {
      if (list[index].unread) return list[index];
    }

    return null;
  }

  function snapshot(notification, uid) {
    const receivedAt = Date.now();
    const expireTimeout = Number(notification.expireTimeout || 0);
    const timeoutMs = notification.urgency === NotificationUrgency.Critical
      ? 0
      : (expireTimeout > 0 ? Math.max(3500, Math.min(12000, Math.round(expireTimeout * 1000))) : defaultToastTimeoutMs);

    return {
      uid: uid,
      id: notification.id,
      notification: notification,
      live: true,
      unread: !notification.lastGeneration,
      transient: notification.transient,
      resident: notification.resident,
      urgency: notification.urgency,
      appName: cleanText(notification.appName),
      desktopEntry: cleanText(notification.desktopEntry),
      appIcon: String(notification.appIcon || ""),
      summary: cleanText(notification.summary),
      body: cleanText(notification.body),
      image: String(notification.image || ""),
      receivedAt: receivedAt,
      expireTimeout: expireTimeout,
      toastExpiresAt: timeoutMs > 0 ? receivedAt + timeoutMs : 0,
      lastGeneration: notification.lastGeneration
    };
  }

  function trackNotification(notification) {
    if (!notification) return;

    notification.tracked = true;

    const uid = nextUid;
    nextUid += 1;

    const entry = snapshot(notification, uid);
    const replacedUids = [];
    const nextEntries = entries.filter(existing => {
      if (existing.id !== notification.id) return true;
      replacedUids.push(existing.uid);
      return false;
    });
    nextEntries.unshift(entry);
    setEntries(nextEntries);
    if (replacedUids.length > 0) setToastUids(toastUids.filter(existingUid => replacedUids.indexOf(existingUid) < 0));

    if (!notification.lastGeneration) queueToast(uid);

    notification.closed.connect(function() {
      root.markClosed(uid);
    });
  }

  function queueToast(uid) {
    const nextToastUids = toastUids.filter(existingUid => existingUid !== uid);
    nextToastUids.unshift(uid);
    if (nextToastUids.length > maxToasts) nextToastUids.length = maxToasts;
    setToastUids(nextToastUids);
  }

  function dismissToast(uid) {
    const nextToastUids = toastUids.filter(existingUid => existingUid !== uid);
    if (nextToastUids.length !== toastUids.length) setToastUids(nextToastUids);
  }

  function markClosed(uid) {
    dismissToast(uid);

    const nextEntries = entries.slice();
    let updated = false;

    for (let index = 0; index < nextEntries.length; index += 1) {
      if (nextEntries[index].uid !== uid) continue;
      nextEntries[index] = Object.assign({}, nextEntries[index], { notification: null, live: false });
      updated = true;
      break;
    }

    if (updated) setEntries(nextEntries);
  }

  function markRead(entryOrUid) {
    const uid = typeof entryOrUid === "number" ? entryOrUid : (entryOrUid ? entryOrUid.uid : -1);
    if (uid < 0) return;

    const nextEntries = entries.slice();
    let updated = false;

    for (let index = 0; index < nextEntries.length; index += 1) {
      if (nextEntries[index].uid !== uid || !nextEntries[index].unread) continue;
      nextEntries[index] = Object.assign({}, nextEntries[index], { unread: false });
      updated = true;
      break;
    }

    if (updated) setEntries(nextEntries);
  }

  function markAllRead() {
    if (!hasUnread) return;

    const nextEntries = [];
    for (let index = 0; index < entries.length; index += 1) {
      const entry = entries[index];
      nextEntries.push(entry.unread ? Object.assign({}, entry, { unread: false }) : entry);
    }

    setEntries(nextEntries);
  }

  function invokePrimaryAction(entryOrUid) {
    const entry = typeof entryOrUid === "number" ? entryForUid(entryOrUid) : entryOrUid;
    const action = primaryAction(entry);
    if (!action) return;

    markRead(entry.uid);
    dismissToast(entry.uid);
    action.invoke();
  }

  function closeLive(entryOrUid) {
    const entry = typeof entryOrUid === "number" ? entryForUid(entryOrUid) : entryOrUid;
    if (!entry) return;

    dismissToast(entry.uid);
    if (entry.notification && entry.live) entry.notification.dismiss();
  }

  function forgetEntry(entryOrUid) {
    const uid = typeof entryOrUid === "number" ? entryOrUid : (entryOrUid ? entryOrUid.uid : -1);
    if (uid < 0) return;

    const entry = entryForUid(uid);
    dismissToast(uid);
    setEntries(entries.filter(existing => existing.uid !== uid));
    if (entry && entry.notification && entry.live) entry.notification.dismiss();
  }

  function forgetGroup(groupOrKey) {
    const groupKey = typeof groupOrKey === "string"
      ? groupOrKey
      : (groupOrKey && groupOrKey.key ? String(groupOrKey.key) : "");
    if (groupKey === "") return;

    const liveNotifications = [];
    const removedUids = [];
    const nextEntries = [];

    for (let index = 0; index < entries.length; index += 1) {
      const entry = entries[index];
      if (sourceKey(entry) !== groupKey) {
        nextEntries.push(entry);
        continue;
      }

      removedUids.push(entry.uid);
      if (entry.notification && entry.live) liveNotifications.push(entry.notification);
    }

    if (removedUids.length === 0) return;

    setEntries(nextEntries);
    setToastUids(toastUids.filter(existingUid => removedUids.indexOf(existingUid) < 0));

    for (let index = 0; index < liveNotifications.length; index += 1) {
      liveNotifications[index].dismiss();
    }
  }

  function clearEntries() {
    const liveNotifications = [];

    for (let index = 0; index < entries.length; index += 1) {
      const entry = entries[index];
      if (entry.notification && entry.live) liveNotifications.push(entry.notification);
    }

    setEntries([]);
    setToastUids([]);

    for (let index = 0; index < liveNotifications.length; index += 1) {
      liveNotifications[index].dismiss();
    }
  }

  NotificationServer {
    id: notificationServer

    persistenceSupported: true
    actionsSupported: true
    imageSupported: true
    keepOnReload: true

    onNotification: function(notification) {
      root.trackNotification(notification);
    }
  }
}
