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
  property var oskCommand: ["wvkbd-mobintl"]
  property int oskFallbackDelayMs: 180
  property int oskFallbackHeight: 320

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
    Qt.inputMethod.hide();
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
      refreshLauncherResults();
    }
  }

  IpcHandler {
    target: "launcher"
    function toggle(): void {
      toggleLauncher();
    }
    function open(): void {
      openLauncher("");
    }
    function close(): void {
      closeLauncher();
    }
    function search(query: string): void {
      openLauncher(query);
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: launcherWindow
      property var modelData
      property bool oskFromTouch: false
      property real keyboardInset: {
        if (!oskFromTouch && !oskProcess.running) return 0;
        const qtKeyboard = (Qt.inputMethod.visible || Qt.inputMethod.animating)
          ? Qt.inputMethod.keyboardRectangle.height
          : 0;
        const fallbackKeyboard = oskProcess.running ? root.oskFallbackHeight : 0;
        return Math.max(qtKeyboard, fallbackKeyboard);
      }
      screen: modelData

      visible: launcherOpen
      anchors { left: true; right: true; top: true; bottom: true }
      exclusionMode: ExclusionMode.Ignore
      aboveWindows: true
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

      function focusSearch(fromTouch) {
        oskFromTouch = fromTouch;
        searchInput.forceActiveFocus();
        if (!fromTouch) return;
        Qt.inputMethod.show();
        oskFallbackTimer.restart();
      }

      function moveSelectionBy(delta) {
        if (launcherResults.length === 0) return;
        root.setLauncherSelection(root.launcherSelectedIndex + delta);
      }

      function pageItemCount(page) {
        const start = page * root.launcherPageSize;
        return Math.max(0, Math.min(root.launcherPageSize, launcherResults.length - start));
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
        if (launcherResults.length === 0) return;

        const page = Math.floor(root.launcherSelectedIndex / root.launcherPageSize);
        const pageOffset = root.launcherSelectedIndex - page * root.launcherPageSize;
        const row = Math.floor(pageOffset / root.launcherColumns);
        const col = pageOffset % root.launcherColumns;
        const maxPage = Math.max(0, Math.ceil(launcherResults.length / root.launcherPageSize) - 1);

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

      function focusGrid() {
        launcherContent.forceActiveFocus();
      }

      function stopOsk() {
        oskFallbackTimer.stop();
        if (oskProcess.running) oskProcess.running = false;
        Qt.inputMethod.hide();
        oskFromTouch = false;
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
          const qtKeyboardVisible = Qt.inputMethod.visible || Qt.inputMethod.keyboardRectangle.height > 0;
          if (!qtKeyboardVisible && !oskProcess.running) oskProcess.running = true;
        }
      }

      Connections {
        target: Qt.inputMethod
        function onVisibleChanged() {
          if (Qt.inputMethod.visible && oskProcess.running) oskProcess.running = false;
        }
      }

      UiScrim {
        anchors.fill: parent
      }

      MouseArea {
        anchors.fill: parent
        onClicked: closeLauncher()
      }

      Item {
        id: launcherContent
        width: Math.min(parent.width - 36, 980)
        height: launcherColumn.implicitHeight
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(20, Math.round((parent.height - keyboardInset - height) / 2))
        focus: launcherWindow.visible && !searchInput.activeFocus
        LayoutMirroring.enabled: false
        LayoutMirroring.childrenInherit: true

        Keys.onPressed: function(event) {
          if (searchInput.activeFocus) return;

          if (event.key === Qt.Key_Escape) {
            closeLauncher();
            event.accepted = true;
            return;
          }

          if (launcherResults.length > 0) {
            switch (event.key) {
            case Qt.Key_Left:
              moveHorizontal(-1);
              event.accepted = true;
              return;
            case Qt.Key_Right:
              moveHorizontal(1);
              event.accepted = true;
              return;
            case Qt.Key_Up:
              if ((root.launcherSelectedIndex % pagerArea.pageSize) < pagerArea.columns) {
                focusSearch(false);
              } else {
                moveSelectionBy(-pagerArea.columns);
              }
              event.accepted = true;
              return;
            case Qt.Key_Down:
              moveSelectionBy(pagerArea.columns);
              event.accepted = true;
              return;
            case Qt.Key_PageUp:
              moveSelectionBy(-pagerArea.pageSize);
              event.accepted = true;
              return;
            case Qt.Key_PageDown:
              moveSelectionBy(pagerArea.pageSize);
              event.accepted = true;
              return;
            case Qt.Key_Home:
              root.setLauncherSelection(0);
              event.accepted = true;
              return;
            case Qt.Key_End:
              root.setLauncherSelection(launcherResults.length - 1);
              event.accepted = true;
              return;
            case Qt.Key_Enter:
            case Qt.Key_Return:
              launchEntry(launcherResults[root.launcherSelectedIndex]);
              event.accepted = true;
              return;
            }
          }

          const modifiers = event.modifiers;
          const hasMetaModifier = modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier);
          if (!hasMetaModifier && event.text && event.text.length > 0) {
            focusSearch(false);
            launcherQuery = event.text;
            searchInput.text = launcherQuery;
            searchInput.cursorPosition = launcherQuery.length;
            event.accepted = true;
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
                anchors.rightMargin: launcherQuery === "" ? 18 : 52
                verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textXl
                color: Theme.text
                selectionColor: Theme.selection
                selectedTextColor: Theme.textOnAccent
                clip: true
                selectByMouse: true
                text: launcherQuery
                onTextEdited: launcherQuery = text
                onAccepted: if (launcherResults.length > 0) launchEntry(launcherResults[0])
                Keys.onEscapePressed: closeLauncher()
                Keys.onDownPressed: launcherWindow.focusGrid()
                onActiveFocusChanged: {
                  if (activeFocus) {
                    if (launcherWindow.oskFromTouch) {
                      Qt.inputMethod.show();
                      oskFallbackTimer.restart();
                    }
                  } else if (launcherWindow.oskFromTouch || oskProcess.running) {
                    launcherWindow.stopOsk();
                  }

                  if (!activeFocus && launcherWindow.visible) launcherWindow.focusGrid();
                }

                TapHandler {
                  acceptedDevices: PointerDevice.TouchScreen
                  onTapped: launcherWindow.focusSearch(true)
                }
              }

              UiText {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 18
                visible: launcherQuery === "" && !searchInput.activeFocus
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
                visible: launcherQuery !== ""

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
                  onClicked: launcherQuery = ""
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
            property int pageGap: 20
            property int arrowGutter: 76
            property real tileWidth: Math.floor((pageView.width - (columns - 1) * tileSpacing) / columns)
            property int pageSize: root.launcherPageSize
            property int pageCount: Math.max(1, Math.ceil(launcherResults.length / pageSize))

            function syncToPage(page, align) {
              const maxPage = Math.max(0, pageCount - 1);
              const clampedPage = Math.max(0, Math.min(page, maxPage));
              if (root.launcherPage !== clampedPage) root.launcherPage = clampedPage;
              const indexChanged = pageView.currentIndex !== clampedPage;
              if (indexChanged) pageView.currentIndex = clampedPage;
              if ((align || indexChanged) && pageView.count > 0)
                pageView.positionViewAtIndex(clampedPage, ListView.Beginning);
            }

            onPageCountChanged: {
              syncToPage(root.launcherPage, true);
            }

            Connections {
              target: root
              function onLauncherPageChanged() {
                syncToPage(root.launcherPage, false);
              }
            }

            ListView {
              id: pageView
              anchors.fill: parent
              anchors.leftMargin: pagerArea.arrowGutter
              anchors.rightMargin: pagerArea.arrowGutter
              clip: true
              orientation: ListView.Horizontal
              layoutDirection: Qt.LeftToRight
              model: pagerArea.pageCount
              spacing: pagerArea.pageGap
              snapMode: ListView.SnapOneItem
              boundsBehavior: Flickable.StopAtBounds
              highlightMoveDuration: Theme.motionSlow
              interactive: pagerArea.pageCount > 1

              Component.onCompleted: {
                pagerArea.syncToPage(root.launcherPage, true);
              }

              onCurrentIndexChanged: {
                if (root.launcherPage !== currentIndex) root.launcherPage = currentIndex;

                if (launcherResults.length === 0) return;
                const pageStart = currentIndex * pagerArea.pageSize;
                const pageEnd = Math.min(launcherResults.length - 1, pageStart + pagerArea.pageSize - 1);
                if (root.launcherSelectedIndex < pageStart || root.launcherSelectedIndex > pageEnd) {
                  root.setLauncherSelection(pageStart);
                }
              }

              delegate: Item {
                id: pageDelegate
                property int pageBase: index * pagerArea.pageSize
                property int pageItemCount: Math.max(0, Math.min(pagerArea.pageSize, launcherResults.length - pageBase))
                width: pageView.width
                height: pageView.height

                Grid {
                  columns: pagerArea.columns
                  rows: pagerArea.rows
                  rowSpacing: pagerArea.tileSpacing
                  columnSpacing: pagerArea.tileSpacing
                  anchors.centerIn: parent

                  Repeater {
                    model: pageDelegate.pageItemCount

                    delegate: Item {
                      id: tile
                      property int absoluteIndex: pageDelegate.pageBase + index
                      property var entry: launcherResults[absoluteIndex]
                      property bool selected: root.launcherSelectedIndex === absoluteIndex
                      width: pagerArea.tileWidth
                      height: pagerArea.tileHeight

                      MouseArea {
                        id: tileTouch
                        anchors.fill: parent
                        onPressed: root.setLauncherSelection(tile.absoluteIndex)
                        onClicked: launchEntry(tile.entry)
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

            Item {
              id: prevPageButton
              width: 64
              height: pagerArea.tileHeight
              x: pageView.x - width - 6
              y: Math.round(pageView.y + (pageView.height - height) / 2)
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
                onClicked: pagerArea.syncToPage(root.launcherPage - 1, true)
              }
            }

            Item {
              id: nextPageButton
              width: 64
              height: pagerArea.tileHeight
              x: pageView.x + pageView.width + 6
              y: Math.round(pageView.y + (pageView.height - height) / 2)
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
                onClicked: pagerArea.syncToPage(root.launcherPage + 1, true)
              }
            }

            UiText {
              anchors.centerIn: pageView
              visible: launcherResults.length === 0
              text: "No matching applications"
              tone: "subtle"
              size: "xl"
            }
          }
        }
      }

      onVisibleChanged: {
        if (visible) {
          focusGrid();
          pagerArea.syncToPage(root.launcherPage, true);
        }
        else stopOsk();
      }
    }
  }
}
