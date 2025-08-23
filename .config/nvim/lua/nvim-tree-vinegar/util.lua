local treeCore = require("nvim-tree.core")
local treeView = require("nvim-tree.view")

local M = {
  _fixHeight = false
}

function M.setFixHeight(val)
  M._fixHeight = val
end

function M.fixHeight()
  -- By removing the window width/height fixing any splits will split the current browser
  treeView.View.winopts.winfixwidth = nil
  treeView.View.winopts.winfixheight = nil
end

-- Local copy of nvim-tree.view.save_tab_state since it is local
function M.save_tab_state()
  local tabpage = vim.api.nvim_get_current_tabpage()
  local winnr = treeView.get_winnr()

  if winnr ~= nil then
    treeView.View.cursors[tabpage] = vim.api.nvim_win_get_cursor(winnr)
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
  treeView.restore_tab_state()
end

return M
