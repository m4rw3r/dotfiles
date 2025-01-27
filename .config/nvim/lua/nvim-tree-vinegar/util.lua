local treeView = require("nvim-tree.view")
local treeCore = require("nvim-tree.core")

local M = {}

-- Local copy of nvim-tree.view.save_tab_state since it is local
function M.saveTabState()
  local tabpage = vim.api.nvim_get_current_tabpage()
  local winnr = treeView.get_winnr()

  if winnr ~= nil then
    treeView.View.cursors[tabpage] = vim.api.nvim_win_get_cursor(winnr)
  end
end

function M.drawTree()
  local explorer = treeCore.get_explorer()

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

return M
