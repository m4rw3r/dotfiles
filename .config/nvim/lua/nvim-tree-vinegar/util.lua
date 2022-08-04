local treeView = require("nvim-tree.view")

local M = {}

-- Local copy of nvim-tree.view.save_tab_state since it is local
function M.saveTabState()
  local tabpage = vim.api.nvim_get_current_tabpage()
  local winnr = treeView.get_winnr()

  if winnr ~= nil then
    treeView.View.cursors[tabpage] = vim.api.nvim_win_get_cursor(winnr)
  end
end

return M
