pragma ComponentBehavior: Bound

import QtQml
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "theme"
import "ui/primitives"

Item {
  id: root

  signal launcherOpening()

  property bool launcherOpen: false
  property string launcherQuery: ""
  property var launcherResults: []
  property int launcherResultLimit: 240
  property int launcherPage: 0
  property int launcherColumns: 4
  property int launcherRows: 3
  property int launcherPageSize: launcherColumns * launcherRows
  property int launcherSelectedIndex: 0
  property var activeScreen: null
  readonly property var inputMethod: Qt.inputMethod
  readonly property real inputMethodHeight: inputMethod ? inputMethod.keyboardRectangle.height : 0
  readonly property bool inputMethodVisible: inputMethod
    ? inputMethod.visible || inputMethod.animating || inputMethodHeight > 0
    : false
  readonly property bool hasLauncherResults: launcherResults.length > 0
  readonly property var selectedLauncherEntry: hasLauncherResults
    ? launcherResults[launcherSelectedIndex]
    : null
  property var oskCommand: ["wvkbd-mobintl"]
  property int oskFallbackDelayMs: 180
  property int oskFallbackHeight: 320

  function showInputPanel() {
    if (inputMethod) inputMethod.show();
  }

  function hideInputPanel() {
    if (inputMethod) inputMethod.hide();
  }

  function ensureActiveScreen() {
    const screens = Quickshell.screens;
    if (screens.length === 0) {
      activeScreen = null;
      return;
    }

    for (let i = 0; i < screens.length; i += 1) {
      if (screens[i] === activeScreen) return;
    }

    activeScreen = screens[0];
  }

  function clampLauncherSelection() {
    if (launcherResults.length === 0) {
      launcherSelectedIndex = 0;
      launcherPage = 0;
      return;
    }

    const maxIndex = launcherResults.length - 1;
    launcherSelectedIndex = Math.max(0, Math.min(launcherSelectedIndex, maxIndex));

    const maxPage = Math.max(0, Math.ceil(launcherResults.length / launcherPageSize) - 1);
    const targetPage = Math.floor(launcherSelectedIndex / launcherPageSize);
    launcherPage = Math.max(0, Math.min(targetPage, maxPage));
  }

  function setLauncherSelection(index) {
    launcherSelectedIndex = index;
    clampLauncherSelection();
  }

  function normalizeText(value) {
    return String(value || "").toLowerCase();
  }

  function refreshLauncherResults() {
    const query = normalizeText(launcherQuery).trim();
    const entries = DesktopEntries.applications.values;
    const ranked = [];

    for (let i = 0; i < entries.length; i += 1) {
      const entry = entries[i];
      const name = normalizeText(entry.name);
      const genericName = normalizeText(entry.genericName);
      const comment = normalizeText(entry.comment);
      const id = normalizeText(entry.id);
      const keywords = normalizeText((entry.keywords || []).join(" "));

      let score = 0;
      if (query !== "") {
        if (name.startsWith(query)) score = 500;
        else if (name.includes(query)) score = 420;
        else if (genericName.startsWith(query)) score = 340;
        else if (genericName.includes(query)) score = 290;
        else if (keywords.includes(query)) score = 260;
        else if (id.includes(query)) score = 200;
        else if (comment.includes(query)) score = 120;
        else continue;

        if (id === query) score += 300;
      }

      ranked.push({
        entry,
        score,
        sortKey: name !== "" ? name : id
      });
    }

    ranked.sort((a, b) => {
      if (b.score !== a.score) return b.score - a.score;
      return a.sortKey.localeCompare(b.sortKey);
    });

    const limited = [];
    const limit = Math.min(ranked.length, launcherResultLimit);

    for (let i = 0; i < limit; i += 1) {
      limited.push(ranked[i].entry);
    }

    launcherResults = limited;
  }

  function openLauncher(query) {
    launcherOpening();
    ensureActiveScreen();
    launcherOpen = true;
    launcherQuery = query === undefined ? "" : String(query);
    launcherPage = 0;
    launcherSelectedIndex = 0;
    refreshLauncherResults();
  }

  function closeLauncher() {
    launcherOpen = false;
    launcherQuery = "";
    launcherPage = 0;
    launcherSelectedIndex = 0;
    hideInputPanel();
    refreshLauncherResults();
  }

  function toggleLauncher() {
    if (launcherOpen) closeLauncher();
    else openLauncher("");
  }

  function launchEntry(entry) {
    if (!entry) return;
    entry.execute();
    closeLauncher();
  }

  onLauncherQueryChanged: {
    launcherPage = 0;
    launcherSelectedIndex = 0;
    refreshLauncherResults();
  }
  onLauncherResultsChanged: clampLauncherSelection()
  Component.onCompleted: refreshLauncherResults()

  Connections {
    target: DesktopEntries
    function onApplicationsChanged() {
      root.refreshLauncherResults();
    }
  }

  IpcHandler {
    target: "launcher"
    function toggle(): void {
      root.toggleLauncher();
    }
    function open(): void {
      root.openLauncher("");
    }
    function close(): void {
      root.closeLauncher();
    }
    function search(query: string): void {
      root.openLauncher(query);
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: launcherWindow

      property var modelData
      property bool oskFromTouch: false
      property bool refocusSearch: false
      property bool isActiveWindow: root.activeScreen === null
        ? (Quickshell.screens.length > 0 && Quickshell.screens[0] === launcherWindow.modelData)
        : root.activeScreen === launcherWindow.modelData
      property real keyboardInset: {
        if (!oskFromTouch && !oskProcess.running) return 0;
        const qtKeyboard = root.inputMethodVisible ? root.inputMethodHeight : 0;
        const fallbackKeyboard = oskProcess.running ? root.oskFallbackHeight : 0;
        return Math.max(qtKeyboard, fallbackKeyboard);
      }
      screen: modelData

      visible: root.launcherOpen
      anchors { left: true; right: true; top: true; bottom: true }
      exclusionMode: ExclusionMode.Ignore
      aboveWindows: true
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: launcherWindow.isActiveWindow
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

      function focusSearch(fromTouch) {
        root.activeScreen = launcherWindow.modelData;
        oskFromTouch = fromTouch;
        searchInput.forceActiveFocus();
        if (!fromTouch) return;
        root.showInputPanel();
        oskFallbackTimer.restart();
      }

      function moveSelectionBy(delta) {
        if (root.launcherResults.length === 0) return;
        root.setLauncherSelection(root.launcherSelectedIndex + delta);
      }

      function pageItemCount(page) {
        const start = page * root.launcherPageSize;
        return Math.max(0, Math.min(root.launcherPageSize, root.launcherResults.length - start));
      }

      function rowItemCount(page, row) {
        const count = pageItemCount(page);
        const rowStart = row * root.launcherColumns;
        if (rowStart >= count) return 0;
        return Math.min(root.launcherColumns, count - rowStart);
      }

      function clampRow(page, row) {
        const count = pageItemCount(page);
        if (count <= 0) return 0;
        const maxRow = Math.ceil(count / root.launcherColumns) - 1;
        return Math.max(0, Math.min(row, maxRow));
      }

      function moveHorizontal(direction) {
        if (root.launcherResults.length === 0) return;

        const page = Math.floor(root.launcherSelectedIndex / root.launcherPageSize);
        const pageOffset = root.launcherSelectedIndex - page * root.launcherPageSize;
        const row = Math.floor(pageOffset / root.launcherColumns);
        const col = pageOffset % root.launcherColumns;
        const maxPage = Math.max(0, Math.ceil(root.launcherResults.length / root.launcherPageSize) - 1);

        if (direction > 0) {
          const currentRowCount = rowItemCount(page, row);
          if (col < currentRowCount - 1) {
            root.setLauncherSelection(root.launcherSelectedIndex + 1);
            return;
          }

          if (page >= maxPage) return;

          const targetPage = page + 1;
          const targetRow = clampRow(targetPage, row);
          const targetIndex = targetPage * root.launcherPageSize + targetRow * root.launcherColumns;
          root.setLauncherSelection(targetIndex);
          return;
        }

        if (col > 0) {
          root.setLauncherSelection(root.launcherSelectedIndex - 1);
          return;
        }

        if (page <= 0) return;

        const targetPage = page - 1;
        const targetRow = clampRow(targetPage, row);
        const targetRowCount = rowItemCount(targetPage, targetRow);
        const targetCol = Math.max(0, targetRowCount - 1);
        const targetIndex = targetPage * root.launcherPageSize + targetRow * root.launcherColumns + targetCol;
        root.setLauncherSelection(targetIndex);
      }

      function moveVertical(direction) {
        if (root.launcherResults.length === 0) return;

        const page = Math.floor(root.launcherSelectedIndex / root.launcherPageSize);
        const pageOffset = root.launcherSelectedIndex - page * root.launcherPageSize;
        const row = Math.floor(pageOffset / root.launcherColumns);
        const col = pageOffset % root.launcherColumns;
        if (direction < 0) {
          if (row <= 0) {
            launcherWindow.focusSearch(false);
            return;
          }

          const targetRow = row - 1;
          const targetCol = Math.min(col, rowItemCount(page, targetRow) - 1);
          const targetIndex = page * root.launcherPageSize + targetRow * root.launcherColumns + targetCol;
          root.setLauncherSelection(targetIndex);
          return;
        }

        const nextRow = row + 1;
        const nextRowCount = rowItemCount(page, nextRow);
        if (nextRowCount > 0) {
          const targetCol = Math.min(col, nextRowCount - 1);
          const targetIndex = page * root.launcherPageSize + nextRow * root.launcherColumns + targetCol;
          root.setLauncherSelection(targetIndex);
        }
      }

      function focusGrid() {
        root.activeScreen = launcherWindow.modelData;
        launcherContent.forceActiveFocus();
      }

      function syncQueryFromSearchInput() {
        root.launcherQuery = searchInput.text;
      }

      function editSearchFromGrid(event) {
        const modifiers = event.modifiers;
        const hasMetaModifier = modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier);
        if (hasMetaModifier) return false;

        if (event.key === Qt.Key_Backspace) {
          launcherWindow.focusSearch(false);
          if (searchInput.cursorPosition > 0) {
            searchInput.remove(searchInput.cursorPosition - 1, 1);
            launcherWindow.syncQueryFromSearchInput();
          }
          return true;
        }

        if (event.key === Qt.Key_Delete) {
          launcherWindow.focusSearch(false);
          if (searchInput.cursorPosition < searchInput.length) {
            searchInput.remove(searchInput.cursorPosition, 1);
            launcherWindow.syncQueryFromSearchInput();
          }
          return true;
        }

        if (!event.text || event.text.length === 0) return false;

        launcherWindow.focusSearch(false);
        searchInput.insert(searchInput.cursorPosition, event.text);
        launcherWindow.syncQueryFromSearchInput();
        return true;
      }

      function stopOsk() {
        oskFallbackTimer.stop();
        if (oskProcess.running) oskProcess.running = false;
        root.hideInputPanel();
        oskFromTouch = false;
      }

      function syncWindowState() {
        if (!launcherWindow.visible) {
          pageFrame.syncStripToPage(0, true);
          launcherWindow.stopOsk();
          return;
        }

        pagerArea.setPage(root.launcherPage);
        Qt.callLater(function() {
          if (!launcherWindow.visible) return;
          pageFrame.syncStripToPage(root.launcherPage, true);
        });

        if (launcherWindow.isActiveWindow) launcherContent.forceActiveFocus();
        else launcherWindow.stopOsk();
      }

      Process {
        id: oskProcess
        command: root.oskCommand
      }

      Timer {
        id: oskFallbackTimer
        interval: root.oskFallbackDelayMs
        repeat: false
        onTriggered: {
          if (!launcherWindow.oskFromTouch || !searchInput.activeFocus) return;
          if (!root.inputMethodVisible && !oskProcess.running) oskProcess.running = true;
        }
      }

      Connections {
        target: root.inputMethod
        function onVisibleChanged() {
          if (root.inputMethodVisible && oskProcess.running) oskProcess.running = false;
        }
      }

      UiScrim {
        anchors.fill: parent
      }

      MouseArea {
        anchors.fill: parent
        onClicked: root.closeLauncher()
      }

      Item {
        id: launcherContent
        width: Math.min(parent.width - 36, 980)
        height: launcherColumn.implicitHeight
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(20, Math.round((parent.height - launcherWindow.keyboardInset - height) / 2))
        focus: launcherWindow.visible && !searchInput.activeFocus
        LayoutMirroring.enabled: false
        LayoutMirroring.childrenInherit: true
        Keys.priority: Keys.BeforeItem

        Keys.onPressed: function(event) {
          if (!launcherWindow.visible || searchInput.activeFocus) return;

          if (event.key === Qt.Key_Escape) {
            root.closeLauncher();
            event.accepted = true;
            return;
          }

          if (root.hasLauncherResults) {
            switch (event.key) {
            case Qt.Key_Left:
              launcherWindow.moveHorizontal(-1);
              event.accepted = true;
              return;
            case Qt.Key_Right:
              launcherWindow.moveHorizontal(1);
              event.accepted = true;
              return;
            case Qt.Key_Up:
              launcherWindow.moveVertical(-1);
              event.accepted = true;
              return;
            case Qt.Key_Down:
              launcherWindow.moveVertical(1);
              event.accepted = true;
              return;
            case Qt.Key_PageUp:
              launcherWindow.moveSelectionBy(-pagerArea.pageSize);
              event.accepted = true;
              return;
            case Qt.Key_PageDown:
              launcherWindow.moveSelectionBy(pagerArea.pageSize);
              event.accepted = true;
              return;
            case Qt.Key_Home:
              root.setLauncherSelection(0);
              event.accepted = true;
              return;
            case Qt.Key_End:
              root.setLauncherSelection(root.launcherResults.length - 1);
              event.accepted = true;
              return;
            case Qt.Key_Enter:
            case Qt.Key_Return:
              root.launchEntry(root.selectedLauncherEntry);
              event.accepted = true;
              return;
            }
          }

          if (launcherWindow.editSearchFromGrid(event)) {
            event.accepted = true;
            return;
          }
        }

        Behavior on y {
          NumberAnimation {
            duration: Theme.motionBase
            easing.type: Easing.OutCubic
          }
        }

        MouseArea {
          anchors.fill: parent
        }

        Column {
          id: launcherColumn
          anchors.fill: parent
          spacing: 18

          Item {
            width: parent.width
            height: 64

            UiSurface {
              id: searchBar
              width: Math.max(0, parent.width - pagerArea.arrowGutter * 2)
              height: parent.height
              anchors.horizontalCenter: parent.horizontalCenter
              tone: "field"
              outlined: true
              radius: Theme.radiusMd

              TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: searchInput.text === "" ? 18 : 52
                verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textXl
                color: Theme.text
                selectionColor: Theme.selection
                selectedTextColor: Theme.textOnAccent
                clip: true
                selectByMouse: true
                onTextEdited: {
                  if (!activeFocus) launcherWindow.focusSearch(false);
                  root.launcherQuery = searchInput.text;
                }
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function(event) {
                  if (event.key !== Qt.Key_Enter && event.key !== Qt.Key_Return) return;

                  event.accepted = true;
                  if (!root.selectedLauncherEntry) return;
                  root.launchEntry(root.selectedLauncherEntry);
                }
                Keys.onEscapePressed: root.closeLauncher()
                Keys.onDownPressed: launcherWindow.focusGrid()
                onActiveFocusChanged: {
                  if (activeFocus) {
                    if (launcherWindow.oskFromTouch) {
                      root.showInputPanel();
                      oskFallbackTimer.restart();
                    }
                  } else if (launcherWindow.refocusSearch) {
                    Qt.callLater(function() {
                      launcherWindow.refocusSearch = false;
                      searchInput.forceActiveFocus();
                      if (launcherWindow.oskFromTouch) {
                        root.showInputPanel();
                        oskFallbackTimer.restart();
                      }
                    });
                    return;
                  } else if (launcherWindow.oskFromTouch || oskProcess.running) {
                    launcherWindow.stopOsk();
                  }

                  if (!activeFocus && launcherWindow.visible && launcherWindow.isActiveWindow) {
                    launcherWindow.focusGrid();
                  }
                }

                TapHandler {
                  acceptedDevices: PointerDevice.TouchScreen
                  onTapped: launcherWindow.focusSearch(true)
                }

                Binding on text {
                  when: !searchInput.activeFocus || !launcherWindow.isActiveWindow
                  restoreMode: Binding.RestoreNone
                  value: root.launcherQuery
                }
              }

              UiText {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 18
                visible: searchInput.text === "" && !searchInput.activeFocus
                text: "Search apps"
                tone: "subtle"
                size: "lg"
              }

              Item {
                id: clearButton
                width: 34
                height: 34
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                visible: searchInput.text !== ""

                UiText {
                  anchors.centerIn: parent
                  text: "x"
                  color: clearTouch.pressed ? Theme.textSubtle : Theme.textMuted
                  size: "xl"
                  font.weight: Font.DemiBold
                }

                MouseArea {
                  id: clearTouch
                  anchors.fill: parent
                  onPressed: launcherWindow.refocusSearch = true
                  onCanceled: launcherWindow.refocusSearch = false
                  onClicked: {
                    root.launcherQuery = "";
                    searchInput.text = "";
                    searchInput.cursorPosition = 0;
                    searchInput.forceActiveFocus();
                    launcherWindow.refocusSearch = false;
                  }
                }
              }
            }
          }

          Item {
            id: pagerArea
            width: parent.width
            height: rows * tileHeight + Math.max(0, rows - 1) * tileSpacing
            property int columns: root.launcherColumns
            property int rows: root.launcherRows
            property int tileHeight: 122
            property int tileSpacing: 14
            property int arrowGutter: 76
            property real tileWidth: Math.floor((pageFrame.width - (columns - 1) * tileSpacing) / columns)
            property int pageSize: root.launcherPageSize
            property int pageCount: Math.max(1, Math.ceil(root.launcherResults.length / pageSize))
            property int currentPageBase: root.launcherPage * pageSize
            property int currentPageItemCount: Math.max(0, Math.min(pageSize, root.launcherResults.length - currentPageBase))

            function setPage(page) {
              const maxPage = Math.max(0, pageCount - 1);
              const clampedPage = Math.max(0, Math.min(page, maxPage));
              if (root.launcherPage !== clampedPage) root.launcherPage = clampedPage;

              if (!root.hasLauncherResults) return;

              const pageStart = clampedPage * pageSize;
              const pageEnd = Math.min(root.launcherResults.length - 1, pageStart + pageSize - 1);
              if (root.launcherSelectedIndex < pageStart || root.launcherSelectedIndex > pageEnd) {
                root.setLauncherSelection(pageStart);
              }
            }

            onPageCountChanged: {
              setPage(root.launcherPage);
              pageFrame.syncStripToPage(root.launcherPage, !launcherWindow.visible);
            }

            Connections {
              target: root
              function onLauncherPageChanged() {
                pagerArea.setPage(root.launcherPage);
                pageFrame.syncStripToPage(root.launcherPage, !launcherWindow.visible);
              }
            }

            Item {
              id: pageFrame
              anchors.fill: parent
              anchors.leftMargin: pagerArea.arrowGutter
              anchors.rightMargin: pagerArea.arrowGutter
              clip: true

              property int dragStartPage: 0
              property real dragStartX: 0

              function clampPage(page) {
                return Math.max(0, Math.min(page, Math.max(0, pagerArea.pageCount - 1)));
              }

              function targetStripX(page) {
                return -clampPage(page) * width;
              }

              function syncStripToPage(page, immediate) {
                const targetX = targetStripX(page);
                stripSnapAnimation.stop();
                if (immediate) {
                  pageStrip.x = targetX;
                  return;
                }

                if (pageStrip.x === targetX) return;

                stripSnapAnimation.from = pageStrip.x;
                stripSnapAnimation.to = targetX;
                stripSnapAnimation.start();
              }

              NumberAnimation {
                id: stripSnapAnimation
                target: pageStrip
                property: "x"
                duration: Theme.motionBase
                easing.type: Easing.OutCubic
              }

              onWidthChanged: syncStripToPage(root.launcherPage, true)

              DragHandler {
                id: pageSwipe

                target: null
                enabled: pagerArea.pageCount > 1
                acceptedDevices: PointerDevice.TouchScreen | PointerDevice.Mouse | PointerDevice.TouchPad
                xAxis.enabled: true
                yAxis.enabled: false
                grabPermissions: PointerHandler.CanTakeOverFromAnything

                onTranslationChanged: {
                  if (!active) return;
                  const minX = Math.min(0, pageFrame.width - pageStrip.width);
                  const nextX = pageFrame.dragStartX + translation.x;
                  pageStrip.x = Math.max(minX, Math.min(0, nextX));
                }

                onActiveChanged: {
                  if (active) {
                    stripSnapAnimation.stop();
                    pageFrame.dragStartPage = root.launcherPage;
                    pageFrame.dragStartX = pageStrip.x;
                    root.activeScreen = launcherWindow.modelData;
                    return;
                  }

                  const delta = pageStrip.x - pageFrame.dragStartX;
                  const threshold = Math.max(120, pageFrame.width * 0.22);
                  let targetPage = pageFrame.dragStartPage;
                  if (Math.abs(delta) >= threshold) targetPage += delta < 0 ? 1 : -1;
                  targetPage = pageFrame.clampPage(targetPage);
                  pagerArea.setPage(targetPage);
                  pageFrame.syncStripToPage(targetPage, false);
                  launcherWindow.focusGrid();
                }
              }

              Item {
                id: pageStrip

                width: Math.max(pageFrame.width, pagerArea.pageCount * pageFrame.width)
                height: pageFrame.height
                x: 0
                Component.onCompleted: pageFrame.syncStripToPage(root.launcherPage, true)

                Repeater {
                  model: pagerArea.pageCount

                  delegate: Item {
                    id: pageItem

                    required property int index
                    property int pageBase: index * pagerArea.pageSize
                    property int pageItemCount: launcherWindow.pageItemCount(index)
                    x: index * pageFrame.width
                    width: pageFrame.width
                    height: pageFrame.height

                    Grid {
                      columns: pagerArea.columns
                      rows: pagerArea.rows
                      rowSpacing: pagerArea.tileSpacing
                      columnSpacing: pagerArea.tileSpacing
                      anchors.centerIn: parent

                      Repeater {
                        model: pageItem.pageItemCount

                        delegate: Item {
                          id: tile
                          required property int index
                          property int absoluteIndex: pageItem.pageBase + index
                          property var entry: root.launcherResults[absoluteIndex]
                          property bool selected: root.launcherSelectedIndex === absoluteIndex
                          width: pagerArea.tileWidth
                          height: pagerArea.tileHeight

                          MouseArea {
                            id: tileTouch
                            anchors.fill: parent
                            onPressed: {
                              root.activeScreen = launcherWindow.modelData;
                              root.setLauncherSelection(tile.absoluteIndex);
                            }
                            onClicked: root.launchEntry(tile.entry)
                          }

                          Column {
                            width: parent.width
                            anchors.centerIn: parent
                            spacing: 7
                            opacity: tileTouch.pressed ? 0.62 : (tile.selected ? 1 : 0.82)
                            scale: tile.selected ? 1.05 : 1

                            Behavior on scale {
                              NumberAnimation {
                                duration: Theme.motionFast
                                easing.type: Easing.OutCubic
                              }
                            }

                            IconImage {
                              anchors.horizontalCenter: parent.horizontalCenter
                              implicitSize: tile.selected ? Theme.iconMd : Theme.iconSm
                              asynchronous: true
                              mipmap: true
                              source: tile.entry.icon !== "" ? `image://icon/${tile.entry.icon}` : "image://icon/application-x-executable"
                            }

                            UiText {
                              width: parent.width
                              horizontalAlignment: Text.AlignHCenter
                              wrapMode: Text.WordWrap
                              maximumLineCount: 2
                              elide: Text.ElideRight
                              text: tile.entry.name
                              color: tile.selected ? Theme.textOnAccent : Theme.text
                              size: "md"
                              font.weight: Font.DemiBold
                            }

                            UiText {
                              width: parent.width
                              horizontalAlignment: Text.AlignHCenter
                              elide: Text.ElideRight
                              visible: tile.entry.genericName !== ""
                              text: tile.entry.genericName
                              color: tile.selected ? Theme.textMuted : Theme.textSubtle
                              size: "sm"
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }

            Item {
              id: prevPageButton
              width: 64
              height: pagerArea.tileHeight
              x: pageFrame.x - width - 6
              y: Math.round(pageFrame.y + (pageFrame.height - height) / 2)
              z: 2
              visible: pagerArea.pageCount > 1
              opacity: root.launcherPage > 0 ? 0.95 : 0.28

              UiText {
                anchors.centerIn: parent
                text: "<"
                color: Theme.text
                font.pixelSize: 32
                font.weight: Font.DemiBold
              }

              MouseArea {
                anchors.fill: parent
                enabled: root.launcherPage > 0
                onClicked: pagerArea.setPage(root.launcherPage - 1)
              }
            }

            Item {
              id: nextPageButton
              width: 64
              height: pagerArea.tileHeight
              x: pageFrame.x + pageFrame.width + 6
              y: Math.round(pageFrame.y + (pageFrame.height - height) / 2)
              z: 2
              visible: pagerArea.pageCount > 1
              opacity: root.launcherPage < pagerArea.pageCount - 1 ? 0.95 : 0.28

              UiText {
                anchors.centerIn: parent
                text: ">"
                color: Theme.text
                font.pixelSize: 32
                font.weight: Font.DemiBold
              }

              MouseArea {
                anchors.fill: parent
                enabled: root.launcherPage < pagerArea.pageCount - 1
                onClicked: pagerArea.setPage(root.launcherPage + 1)
              }
            }

            UiText {
              anchors.centerIn: pageFrame
              visible: !root.hasLauncherResults
              text: "No matching applications"
              tone: "subtle"
              size: "xl"
            }
          }
        }
      }

      onIsActiveWindowChanged: {
        if (!visible) return;
        launcherWindow.syncWindowState();
      }

      onVisibleChanged: {
        launcherWindow.syncWindowState();
      }
    }
  }
}
