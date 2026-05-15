pragma ComponentBehavior: Bound

import QtQml
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "theme"
import "ui/primitives"

Item {
  id: root

  signal launcherOpening
  signal launcherClosed

  property bool launcherOpen: false
  property string launcherQuery: ""
  property int launcherResultLimit: 240
  property int launcherPage: 0
  property int launcherColumns: 4
  property int launcherRows: 3
  property int launcherPageSize: launcherColumns * launcherRows
  property int launcherSelectedIndex: 0
  property string pendingLauncherQuery: ""
  property int focusedOutputLookupDeadlineMs: 90
  property int pendingOpenRequestId: 0
  readonly property var launcherResults: launcherSearch.results
  readonly property var activeScreen: focusedOutput.activeScreen
  readonly property var inputMethod: Qt.inputMethod
  readonly property real inputMethodHeight: inputMethod ? inputMethod.keyboardRectangle.height : 0
  readonly property bool inputMethodVisible: inputMethod ? inputMethod.visible || inputMethod.animating || inputMethodHeight > 0 : false
  readonly property bool hasLauncherResults: launcherResults.length > 0
  readonly property var selectedLauncherEntry: hasLauncherResults ? launcherResults[launcherSelectedIndex] : null
  property var oskCommand: ["wvkbd-mobintl"]
  property int oskFallbackDelayMs: 180
  property int oskFallbackHeight: 320

  function showInputPanel() {
    if (inputMethod)
      inputMethod.show();
  }

  function hideInputPanel() {
    if (inputMethod)
      inputMethod.hide();
  }

  function withAlpha(color, alpha) {
    return Qt.rgba(color.r, color.g, color.b, alpha);
  }

  function setActiveScreen(screen) {
    return focusedOutput.ensureActiveScreen(screen);
  }

  function finishPendingLauncherOpen(requestId, preferredScreen) {
    if (requestId === 0 || requestId !== pendingOpenRequestId)
      return;

    pendingOpenRequestId = 0;
    focusedOutput.ensureActiveScreen(preferredScreen);
    launcherOpen = true;
    launcherQuery = pendingLauncherQuery;
    launcherPage = 0;
    launcherSelectedIndex = 0;
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

  function refreshLauncherResults() {
    launcherSearch.refresh();
  }

  function openLauncher(query) {
    launcherOpening();
    pendingLauncherQuery = query === undefined ? "" : String(query);
    pendingOpenRequestId = focusedOutput.request();
  }

  function closeLauncher() {
    pendingOpenRequestId = 0;
    focusedOutput.cancel();
    launcherOpen = false;
    launcherClosed();
    pendingLauncherQuery = "";
    launcherQuery = "";
    launcherPage = 0;
    launcherSelectedIndex = 0;
    hideInputPanel();
    refreshLauncherResults();
  }

  function toggleLauncher() {
    if (launcherOpen)
      closeLauncher();
    else
      openLauncher("");
  }

  function launchCommand(entry) {
    const entryCommand = [];
    for (let i = 0; i < entry.command.length; i += 1) {
      entryCommand.push(String(entry.command[i]));
    }

    if (entryCommand.length === 0)
      return false;

    const command = ["systemd-run", "--user", "--scope", "--quiet", "--collect"];
    const workingDirectory = String(entry.workingDirectory || "");
    if (workingDirectory !== "")
      command.push(`--working-directory=${workingDirectory}`);

    if (entry.runInTerminal) {
      command.push("alacritty");
      if (workingDirectory !== "")
        command.push("--working-directory", workingDirectory);
      command.push("-e");
    }

    for (let i = 0; i < entryCommand.length; i += 1) {
      command.push(entryCommand[i]);
    }

    Quickshell.execDetached(command);
    return true;
  }

  function launchEntry(entry) {
    if (!entry)
      return;
    if (!launchCommand(entry))
      return;
    closeLauncher();
  }

  onLauncherQueryChanged: {
    launcherPage = 0;
    launcherSelectedIndex = 0;
  }
  onLauncherResultsChanged: clampLauncherSelection()

  LauncherSearchModel {
    id: launcherSearch

    query: root.launcherQuery
    limit: root.launcherResultLimit
  }

  FocusedOutputResolver {
    id: focusedOutput

    deadlineMs: root.focusedOutputLookupDeadlineMs
    onResolved: function (requestId, screen) {
      root.finishPendingLauncherOpen(requestId, screen);
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

    // qmllint disable uncreatable-type
    PanelWindow {
      id: launcherWindow

      property var modelData
      property bool oskFromTouch: false
      property bool refocusSearch: false
      property bool isActiveWindow: root.activeScreen === null ? (Quickshell.screens.length > 0 && Quickshell.screens[0] === launcherWindow.modelData) : root.activeScreen === launcherWindow.modelData
      property real keyboardInset: {
        if (!oskFromTouch && !oskProcess.running)
          return 0;
        const qtKeyboard = root.inputMethodVisible ? root.inputMethodHeight : 0;
        const fallbackKeyboard = oskProcess.running ? root.oskFallbackHeight : 0;
        return Math.max(qtKeyboard, fallbackKeyboard);
      }
      screen: modelData

      visible: root.launcherOpen
      anchors {
        left: true
        right: true
        top: true
        bottom: true
      }
      exclusionMode: ExclusionMode.Ignore
      aboveWindows: true
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: launcherWindow.isActiveWindow ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

      function focusSearch(fromTouch) {
        root.setActiveScreen(launcherWindow.modelData);
        oskFromTouch = fromTouch;
        searchInput.forceActiveFocus();
        if (!fromTouch)
          return;
        root.showInputPanel();
        oskFallbackTimer.restart();
      }

      function moveSelectionBy(delta) {
        launcherPager.moveSelectionBy(delta);
      }

      function moveHorizontal(direction) {
        launcherPager.moveHorizontal(direction);
      }

      function moveVertical(direction) {
        launcherPager.moveVertical(direction);
      }

      function focusGrid() {
        root.setActiveScreen(launcherWindow.modelData);
        launcherContent.forceActiveFocus();
      }

      function syncQueryFromSearchInput() {
        root.launcherQuery = searchInput.text;
      }

      function editSearchFromGrid(event) {
        const modifiers = event.modifiers;
        const hasMetaModifier = modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier);
        if (hasMetaModifier)
          return false;

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

        if (!event.text || event.text.length === 0)
          return false;

        launcherWindow.focusSearch(false);
        searchInput.insert(searchInput.cursorPosition, event.text);
        launcherWindow.syncQueryFromSearchInput();
        return true;
      }

      function stopOsk() {
        oskFallbackTimer.stop();
        if (oskProcess.running)
          oskProcess.running = false;
        root.hideInputPanel();
        oskFromTouch = false;
      }

      function syncWindowState() {
        if (!launcherWindow.visible) {
          launcherPager.syncStripToPage(0, true);
          launcherWindow.stopOsk();
          return;
        }

        launcherPager.setPage(root.launcherPage);
        Qt.callLater(function () {
          if (!launcherWindow.visible)
            return;
          launcherPager.syncStripToPage(root.launcherPage, true);
        });

        if (launcherWindow.isActiveWindow)
          launcherContent.forceActiveFocus();
        else
          launcherWindow.stopOsk();
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
          if (!launcherWindow.oskFromTouch || !searchInput.activeFocus)
            return;
          if (!root.inputMethodVisible && !oskProcess.running)
            oskProcess.running = true;
        }
      }

      Connections {
        target: root.inputMethod
        function onVisibleChanged() {
          if (root.inputMethodVisible && oskProcess.running)
            oskProcess.running = false;
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
        y: Math.max(Theme.gapMd, Math.round((parent.height - launcherWindow.keyboardInset - height) / 2))
        focus: launcherWindow.visible && !searchInput.activeFocus
        LayoutMirroring.enabled: false
        LayoutMirroring.childrenInherit: true
        Keys.priority: Keys.BeforeItem
        readonly property int backdropOuterInset: Theme.gapLg + Theme.gapXs
        readonly property int backdropCoreInset: Theme.gapXs
        readonly property int backdropRadius: Theme.radiusLg + Theme.gapSm
        readonly property int backdropBlurPadding: Theme.gapLg + Theme.gapSm

        Keys.onPressed: function (event) {
          if (!launcherWindow.visible || searchInput.activeFocus)
            return;

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
              launcherWindow.moveSelectionBy(-launcherPager.pageSize);
              event.accepted = true;
              return;
            case Qt.Key_PageDown:
              launcherWindow.moveSelectionBy(launcherPager.pageSize);
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

        Item {
          id: launcherBackdropSource
          anchors.fill: launcherColumn
          anchors.margins: -(launcherContent.backdropOuterInset + launcherContent.backdropBlurPadding)
          visible: false

          Rectangle {
            anchors.fill: parent
            anchors.margins: launcherContent.backdropBlurPadding + launcherContent.backdropOuterInset - launcherContent.backdropCoreInset
            radius: launcherContent.backdropRadius
            color: root.withAlpha(Theme.panelOverlay, 0.52)
          }
        }

        MultiEffect {
          anchors.fill: launcherBackdropSource
          source: launcherBackdropSource
          autoPaddingEnabled: false
          blurEnabled: true
          blur: 1.0
          blurMax: 64
        }

        Rectangle {
          anchors.fill: launcherColumn
          anchors.margins: -launcherContent.backdropCoreInset
          radius: launcherContent.backdropRadius
          color: root.withAlpha(Theme.panelOverlay, 0.9)
          border.width: 1
          border.color: root.withAlpha(Theme.border, 0.65)
        }

        Column {
          id: launcherColumn
          anchors.fill: parent
          spacing: Theme.gapMd

          Item {
            width: parent.width
            height: Theme.controlMd + Theme.gapLg - Theme.nudge

            UiSurface {
              id: searchBar
              width: Math.max(0, launcherPager.tileWidth * 2 + launcherPager.tileSpacing)
              height: parent.height
              anchors.horizontalCenter: parent.horizontalCenter
              tone: "field"
              outlined: true
              radius: Theme.radiusMd

              TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: Theme.gapMd
                anchors.rightMargin: searchInput.text === "" ? Theme.gapMd : Theme.controlMd + Theme.gapXs
                verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textXl
                color: Theme.text
                selectionColor: Theme.selection
                selectedTextColor: Theme.textOnAccent
                clip: true
                selectByMouse: true
                onTextEdited: {
                  if (!activeFocus)
                    launcherWindow.focusSearch(false);
                  root.launcherQuery = searchInput.text;
                }
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function (event) {
                  if (event.key !== Qt.Key_Enter && event.key !== Qt.Key_Return)
                    return;

                  event.accepted = true;
                  if (!root.selectedLauncherEntry)
                    return;
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
                    Qt.callLater(function () {
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
                anchors.leftMargin: Theme.gapMd
                visible: searchInput.text === "" && !searchInput.activeFocus
                text: "Search apps"
                tone: "subtle"
                size: "lg"
              }

              Item {
                id: clearButton
                width: Theme.controlSm
                height: Theme.controlSm
                anchors.right: parent.right
                anchors.rightMargin: Theme.gapSm
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

          LauncherPager {
            id: launcherPager

            width: parent.width
            results: root.launcherResults
            page: root.launcherPage
            selectedIndex: root.launcherSelectedIndex
            columns: root.launcherColumns
            rows: root.launcherRows
            onPageRequested: function (page) {
              root.launcherPage = page;
            }
            onSelectionRequested: function (index) {
              root.setLauncherSelection(index);
            }
            onEntryActivated: function (entry) {
              root.launchEntry(entry);
            }
            onInteractionStarted: root.setActiveScreen(launcherWindow.modelData)
            onFocusSearchRequested: launcherWindow.focusSearch(false)
            onFocusGridRequested: launcherWindow.focusGrid()
          }
        }
      }

      onIsActiveWindowChanged: {
        if (!visible)
          return;
        launcherWindow.syncWindowState();
      }

      onVisibleChanged: {
        launcherWindow.syncWindowState();
      }
    }
    // qmllint enable uncreatable-type
  }
}
