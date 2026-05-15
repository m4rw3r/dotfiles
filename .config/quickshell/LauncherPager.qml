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
  height: rows * tileHeight + Math.max(0, rows - 1) * tileSpacing

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
    anchors.fill: parent
    anchors.leftMargin: root.arrowGutter
    anchors.rightMargin: root.arrowGutter
    clip: true

    property int dragStartPage: 0
    property real dragStartX: 0

    function clampPage(targetPage) {
      return Math.max(0, Math.min(targetPage, Math.max(0, root.pageCount - 1)));
    }

    function targetStripX(targetPage) {
      return -clampPage(targetPage) * width;
    }

    function syncStripToPage(targetPage, immediate) {
      const targetX = targetStripX(targetPage);
      stripSnapAnimation.stop();
      if (immediate) {
        pageStrip.x = targetX;
        return;
      }

      if (pageStrip.x === targetX)
        return;

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
        const minX = Math.min(0, pageFrame.width - pageStrip.width);
        const nextX = pageFrame.dragStartX + translation.x;
        pageStrip.x = Math.max(minX, Math.min(0, nextX));
      }

      onActiveChanged: {
        if (active) {
          stripSnapAnimation.stop();
          pageFrame.dragStartPage = root.page;
          pageFrame.dragStartX = pageStrip.x;
          root.interactionStarted();
          return;
        }

        const delta = pageStrip.x - pageFrame.dragStartX;
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

      width: Math.max(pageFrame.width, root.pageCount * pageFrame.width)
      height: pageFrame.height
      x: 0
      Component.onCompleted: pageFrame.syncStripToPage(root.page, true)

      Repeater {
        model: root.pageCount

        delegate: Item {
          id: pageItem

          required property int index
          property int pageBase: index * root.pageSize
          property int pageItemCount: root.pageItemCount(index)
          x: index * pageFrame.width
          width: pageFrame.width
          height: pageFrame.height

          Grid {
            columns: root.columns
            rows: root.rows
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
