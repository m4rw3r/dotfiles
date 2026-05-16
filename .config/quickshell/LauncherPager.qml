pragma ComponentBehavior: Bound

import QtQuick
import "theme"
import "ui/primitives"

Item {
  id: root

  property var results: []
  property int page: 0
  property int selectedIndex: 0
  property int columns: 4
  property int rows: 3
  readonly property int tileHeight: Theme.controlMd * 2 + Theme.gapLg + Theme.gapXs
  readonly property int tileSpacing: Theme.gapSm
  readonly property int gridHeight: rows * tileHeight + Math.max(0, rows - 1) * tileSpacing
  readonly property int pageIndicatorHeight: Theme.gapXs + Theme.gapMd
  readonly property int arrowGutter: Theme.controlMd + Theme.gapLg + Theme.gapXs
  readonly property real tileWidth: Math.floor((pageFrame.width - (columns - 1) * tileSpacing) / columns)
  readonly property int pageSize: columns * rows
  readonly property int pageCount: Math.max(1, Math.ceil(results.length / pageSize))
  readonly property int currentPageBase: page * pageSize
  readonly property int currentPageItemCount: Math.max(0, Math.min(pageSize, results.length - currentPageBase))
  readonly property bool hasResults: results.length > 0

  signal pageRequested(int page)
  signal selectionRequested(int index)
  signal entryActivated(var entry)
  signal interactionStarted
  signal focusSearchRequested
  signal focusGridRequested

  width: parent ? parent.width : implicitWidth
  height: gridHeight + pageIndicatorHeight

  function pageItemCount(targetPage) {
    const start = targetPage * pageSize;
    return Math.max(0, Math.min(pageSize, results.length - start));
  }

  function rowItemCount(targetPage, row) {
    const count = pageItemCount(targetPage);
    const rowStart = row * columns;
    if (rowStart >= count)
      return 0;
    return Math.min(columns, count - rowStart);
  }

  function clampRow(targetPage, row) {
    const count = pageItemCount(targetPage);
    if (count <= 0)
      return 0;
    const maxRow = Math.ceil(count / columns) - 1;
    return Math.max(0, Math.min(row, maxRow));
  }

  function setPage(targetPage) {
    const maxPage = Math.max(0, pageCount - 1);
    const clampedPage = Math.max(0, Math.min(targetPage, maxPage));
    if (page !== clampedPage)
      pageRequested(clampedPage);

    if (!hasResults)
      return;

    const pageStart = clampedPage * pageSize;
    const pageEnd = Math.min(results.length - 1, pageStart + pageSize - 1);
    if (selectedIndex < pageStart || selectedIndex > pageEnd)
      selectionRequested(pageStart);
  }

  function moveSelectionBy(delta) {
    if (!hasResults)
      return;
    selectionRequested(selectedIndex + delta);
  }

  function moveHorizontal(direction) {
    if (!hasResults)
      return;

    const currentPage = Math.floor(selectedIndex / pageSize);
    const pageOffset = selectedIndex - currentPage * pageSize;
    const row = Math.floor(pageOffset / columns);
    const col = pageOffset % columns;
    const maxPage = Math.max(0, Math.ceil(results.length / pageSize) - 1);

    if (direction > 0) {
      const currentRowCount = rowItemCount(currentPage, row);
      if (col < currentRowCount - 1) {
        selectionRequested(selectedIndex + 1);
        return;
      }

      if (currentPage >= maxPage)
        return;

      const targetPage = currentPage + 1;
      const targetRow = clampRow(targetPage, row);
      selectionRequested(targetPage * pageSize + targetRow * columns);
      return;
    }

    if (col > 0) {
      selectionRequested(selectedIndex - 1);
      return;
    }

    if (currentPage <= 0)
      return;

    const targetPage = currentPage - 1;
    const targetRow = clampRow(targetPage, row);
    const targetRowCount = rowItemCount(targetPage, targetRow);
    const targetCol = Math.max(0, targetRowCount - 1);
    selectionRequested(targetPage * pageSize + targetRow * columns + targetCol);
  }

  function moveVertical(direction) {
    if (!hasResults)
      return;

    const currentPage = Math.floor(selectedIndex / pageSize);
    const pageOffset = selectedIndex - currentPage * pageSize;
    const row = Math.floor(pageOffset / columns);
    const col = pageOffset % columns;
    if (direction < 0) {
      if (row <= 0) {
        focusSearchRequested();
        return;
      }

      const targetRow = row - 1;
      const targetCol = Math.min(col, rowItemCount(currentPage, targetRow) - 1);
      selectionRequested(currentPage * pageSize + targetRow * columns + targetCol);
      return;
    }

    const nextRow = row + 1;
    const nextRowCount = rowItemCount(currentPage, nextRow);
    if (nextRowCount > 0) {
      const targetCol = Math.min(col, nextRowCount - 1);
      selectionRequested(currentPage * pageSize + nextRow * columns + targetCol);
    }
  }

  function syncStripToPage(targetPage, immediate) {
    pageFrame.syncStripToPage(targetPage, immediate);
  }

  onPageCountChanged: {
    setPage(page);
    syncStripToPage(page, !visible);
  }

  onPageChanged: {
    setPage(page);
    syncStripToPage(page, !visible);
  }

  Item {
    id: pageFrame
    height: root.gridHeight
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: root.arrowGutter
    anchors.rightMargin: root.arrowGutter
    clip: true

    property int anchorPage: root.page
    property int dragStartPage: 0
    property bool recenterAfterAnimation: false
    property int recenterTargetPage: 0
    readonly property int renderedPageCount: Math.min(root.pageCount, 3)
    readonly property int windowStartPage: Math.max(0, Math.min(clampPage(anchorPage) - 1, Math.max(0, root.pageCount - renderedPageCount)))

    function clampPage(targetPage) {
      return Math.max(0, Math.min(targetPage, Math.max(0, root.pageCount - 1)));
    }

    function pageInWindow(targetPage) {
      const clampedPage = clampPage(targetPage);
      return clampedPage >= windowStartPage && clampedPage < windowStartPage + renderedPageCount;
    }

    function pageSlot(targetPage) {
      return clampPage(targetPage) - windowStartPage;
    }

    function targetStripX(targetPage) {
      return -pageSlot(targetPage) * width;
    }

    function syncStripToPage(targetPage, immediate) {
      const clampedPage = clampPage(targetPage);
      recenterAfterAnimation = false;
      stripSnapAnimation.stop();

      if (immediate || !pageInWindow(clampedPage)) {
        anchorPage = clampedPage;
        pageStrip.x = targetStripX(clampedPage);
        return;
      }

      const targetX = targetStripX(clampedPage);
      if (pageStrip.x === targetX) {
        anchorPage = clampedPage;
        pageStrip.x = targetStripX(clampedPage);
        return;
      }

      recenterAfterAnimation = true;
      recenterTargetPage = clampedPage;
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
      onStopped: {
        if (!pageFrame.recenterAfterAnimation)
          return;
        pageFrame.recenterAfterAnimation = false;
        pageFrame.anchorPage = pageFrame.recenterTargetPage;
        pageStrip.x = pageFrame.targetStripX(pageFrame.recenterTargetPage);
      }
    }

    onWidthChanged: syncStripToPage(root.page, true)

    DragHandler {
      id: pageSwipe

      target: null
      enabled: root.pageCount > 1
      acceptedDevices: PointerDevice.TouchScreen | PointerDevice.Mouse | PointerDevice.TouchPad
      xAxis.enabled: true
      yAxis.enabled: false
      grabPermissions: PointerHandler.CanTakeOverFromAnything

      onTranslationChanged: {
        if (!active)
          return;
        const startX = pageFrame.targetStripX(pageFrame.dragStartPage);
        const minX = pageFrame.targetStripX(pageFrame.windowStartPage + pageFrame.renderedPageCount - 1);
        const maxX = pageFrame.targetStripX(pageFrame.windowStartPage);
        pageStrip.x = Math.max(minX, Math.min(maxX, startX + translation.x));
      }

      onActiveChanged: {
        if (active) {
          pageFrame.recenterAfterAnimation = false;
          stripSnapAnimation.stop();
          pageFrame.anchorPage = root.page;
          pageFrame.dragStartPage = root.page;
          pageStrip.x = pageFrame.targetStripX(root.page);
          root.interactionStarted();
          return;
        }

        const delta = pageStrip.x - pageFrame.targetStripX(pageFrame.dragStartPage);
        const threshold = Math.max(Theme.controlMd * 2 + Theme.gapLg + Theme.gapXs, pageFrame.width * 0.22);
        let targetPage = pageFrame.dragStartPage;
        if (Math.abs(delta) >= threshold)
          targetPage += delta < 0 ? 1 : -1;
        targetPage = pageFrame.clampPage(targetPage);
        root.setPage(targetPage);
        pageFrame.syncStripToPage(targetPage, false);
        root.focusGridRequested();
      }
    }

    Item {
      id: pageStrip

      width: Math.max(pageFrame.width, pageFrame.renderedPageCount * pageFrame.width)
      height: pageFrame.height
      x: pageFrame.targetStripX(root.page)
      Component.onCompleted: pageFrame.syncStripToPage(root.page, true)

      Repeater {
        model: pageFrame.renderedPageCount

        delegate: Item {
          id: pageItem

          required property int index
          readonly property int pageNumber: pageFrame.windowStartPage + index
          readonly property int pageBase: pageNumber * root.pageSize
          readonly property int pageItemCount: root.pageItemCount(pageNumber)
          x: index * pageFrame.width
          width: pageFrame.width
          height: pageFrame.height

          Grid {
            columns: root.columns
            rows: root.rows
            width: root.columns * root.tileWidth + Math.max(0, root.columns - 1) * root.tileSpacing
            height: root.gridHeight
            rowSpacing: root.tileSpacing
            columnSpacing: root.tileSpacing
            anchors.centerIn: parent

            Repeater {
              model: pageItem.pageItemCount

              delegate: LauncherTile {
                required property int index

                width: root.tileWidth
                height: root.tileHeight
                absoluteIndex: pageItem.pageBase + index
                entry: root.results[absoluteIndex]
                selected: root.selectedIndex === absoluteIndex
                onPressed: function (index) {
                  root.interactionStarted();
                  root.selectionRequested(index);
                }
                onActivated: function (entry) {
                  root.entryActivated(entry);
                }
              }
            }
          }
        }
      }
    }
  }

  Item {
    id: pageDots
    width: pageFrame.width
    height: Theme.gapMd
    anchors.top: pageFrame.bottom
    anchors.topMargin: Theme.gapXs
    anchors.horizontalCenter: pageFrame.horizontalCenter
    visible: root.pageCount > 1

    Row {
      anchors.centerIn: parent
      spacing: 2

      Repeater {
        model: root.pageCount

        delegate: Item {
          id: pageDotDelegate

          required property int index

          width: Theme.gapLg
          height: pageDots.height

          Rectangle {
            anchors.centerIn: parent
            width: pageDotDelegate.index === root.page ? 18 : 7
            height: 7
            radius: height / 2
            color: pageDotDelegate.index === root.page ? Theme.accentStrong : Qt.rgba(Theme.textSubtle.r, Theme.textSubtle.g, Theme.textSubtle.b, 0.38)

            Behavior on width {
              NumberAnimation {
                duration: Theme.motionFast
                easing.type: Easing.OutCubic
              }
            }

            Behavior on color {
              ColorAnimation {
                duration: Theme.motionFast
                easing.type: Easing.OutCubic
              }
            }
          }

          MouseArea {
            anchors.fill: parent
            onClicked: {
              root.interactionStarted();
              root.setPage(pageDotDelegate.index);
              root.focusGridRequested();
            }
          }
        }
      }
    }
  }

  Item {
    id: prevPageButton
    width: 64
    height: root.tileHeight
    x: pageFrame.x - width - 6
    y: Math.round(pageFrame.y + (pageFrame.height - height) / 2)
    z: 2
    visible: root.pageCount > 1
    opacity: root.page > 0 ? 0.95 : 0.28

    UiText {
      anchors.centerIn: parent
      text: "<"
      color: Theme.text
      font.pixelSize: 32
      font.weight: Font.DemiBold
    }

    MouseArea {
      anchors.fill: parent
      enabled: root.page > 0
      onClicked: root.setPage(root.page - 1)
    }
  }

  Item {
    id: nextPageButton
    width: 64
    height: root.tileHeight
    x: pageFrame.x + pageFrame.width + 6
    y: Math.round(pageFrame.y + (pageFrame.height - height) / 2)
    z: 2
    visible: root.pageCount > 1
    opacity: root.page < root.pageCount - 1 ? 0.95 : 0.28

    UiText {
      anchors.centerIn: parent
      text: ">"
      color: Theme.text
      font.pixelSize: 32
      font.weight: Font.DemiBold
    }

    MouseArea {
      anchors.fill: parent
      enabled: root.page < root.pageCount - 1
      onClicked: root.setPage(root.page + 1)
    }
  }

  UiText {
    anchors.centerIn: pageFrame
    visible: !root.hasResults
    text: "No matching applications"
    tone: "subtle"
    size: "xl"
  }
}
