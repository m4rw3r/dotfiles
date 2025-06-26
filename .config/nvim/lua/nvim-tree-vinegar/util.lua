local treeCore = require("nvim-tree.core")

local M = {
  _fixHeight = false
}

function M.setFixHeight(val)
  M._fixHeight = val
end

function M.fixHeight()
  local explorer = treeCore.get_explorer()

  if explorer then
    -- By removing the window width/height fixing any splits will split the current browser
    explorer.view.winopts.winfixwidth = nil
    explorer.view.winopts.winfixheight = nil
  end
end

-- Local copy of nvim-tree.view.save_tab_state since it is local
function M.saveTabState()
  local explorer = treeCore.get_explorer()

  if explorer then
    explorer.view:save_tab_state()
  end
end

function M.drawTree()
  local explorer = treeCore.get_explorer()

  M.fixHeight()

  if explorer then
    explorer.renderer:draw()
  end
end

function M.get_node_at_cursor()
  local explorer = treeCore.get_explorer()

  if explorer then
    return explorer:get_node_at_cursor()
  end
end

function M.restoreTabState()
  local explorer = treeCore.get_explorer()

  if explorer then
    explorer.view:restore_tab_state()
  end
end

return M
