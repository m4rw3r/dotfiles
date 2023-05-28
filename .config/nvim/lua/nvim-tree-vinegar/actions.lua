local util = require("nvim-tree-vinegar.util")

local treeCore = require("nvim-tree.core")
local treeEvents = require("nvim-tree.events")
local treeLib = require("nvim-tree.lib")
local treeRenderer = require("nvim-tree.renderer")
local treeUtils = require("nvim-tree.utils")
local treeView = require("nvim-tree.view")

-- TODO: Add standard actions which do not need to be modified
local M = {}

-- Track the previous window settings when replacing, so we can
-- close the tree view and swap back when opening new splits
local prevWindow = nil

-- Reimplementation of open file which works when we are replacing
-- the current buffer
-- TODO: Maybe a way to split current window, preserving other window-sizes?
function M.openFile(openCb)
  return function(node)
    node = node or treeLib.get_node_at_cursor()

    if not node or node.name == ".." then
      return
    end

    local filename = node.absolute_path

    if node.link_to and not node.nodes then
      filename = node.link_to
    elseif node.nodes ~= nil then
      return treeLib.expand_or_collapse(node)
    end

    openCb(filename)
  end
end

-- Custom changedir which properly handles rerendering in the
-- current window, as well as changing to the directory of a file
function M.changeDir(node)
  node = node or treeLib.get_node_at_cursor()

  if not node then
    return
  end

  local filename = nil

  if node.name == ".." then
    -- TODO: Replace treeUtils with core-functions?
    filename = vim.fn.fnamemodify(treeUtils.path_remove_trailing(treeCore.get_cwd()), ":h")
  elseif node.link_to then
    filename = node.link_to
  else
    filename = node.absolute_path
  end

  while vim.fn.isdirectory(filename) == 0 do
    filename = vim.fn.fnamemodify(treeUtils.path_remove_trailing(filename), ":h")
  end

  -- TODO: Configurable?
  -- TODO: Maybe use local cd (:lcd) instead?
  vim.cmd("cd " .. vim.fn.fnameescape(filename))

  treeCore.init(filename)
  treeRenderer.draw()
end

-- We have to manually reimplement parts of
-- open_replacing_current_buffer in this case to be able to show
-- nvim-tree with a new buffer
function M.openReplacingBuffer()
  local cwd = vim.fn.getcwd();

  -- Save previous window and options so we can restore when closing
  prevWindow = {
    buffer = vim.api.nvim_get_current_buf(),
    opts = {}
  }

  for k, _ in pairs(treeView.View.winopts) do
    prevWindow.opts[k] = vim.opt_local[k]:get()
  end

  -- Reinit if the file we are opening from is not in the current directory
  if not treeCore.get_explorer() or cwd ~= treeCore.get_cwd() then
    treeCore.init(cwd)
  end

  treeView.open_in_win({ hijack_current_buf = false, resize = false })
  treeRenderer.draw()
end

-- Reimplementation of nvim-tree.actions.open-file.edit_in_place which saves
-- the current cursor position.
function M.editInPlace(node)
  node = node or treeLib.get_node_at_cursor()
  local filename = node.absolute_path

  if node.link_to and not node.nodes then
    filename = node.link_to
  elseif node.nodes ~= nil then
    treeLib.expand_or_collapse(node)

    return
  end

  util.saveTabState()
  treeView.abandon_current_window()

  vim.cmd("edit " .. vim.fn.fnameescape(filename))
end

-- Reimplementation of nvim-tree.view.close restoring the original
-- buffer and window options
function M.closeTree()
  local treeWinnr = treeView.get_winnr()

  util.saveTabState()
  treeView.abandon_current_window()

  if not prevWindow or not vim.api.nvim_buf_is_loaded(prevWindow.buffer) then
    vim.cmd("new")
  else
    -- Move to window just in case
    if treeWinnr then
      vim.api.nvim_set_current_win(treeWinnr)
    end

    -- Restore window contents
    vim.api.nvim_set_current_buf(prevWindow.buffer)

    -- Restore window settings
    for k, _ in pairs(treeView.View.winopts) do
      vim.opt_local[k] = prevWindow.opts[k]
    end
  end

  prevWindow = nil

  treeEvents._dispatch_on_tree_close()
end

function M.toggle(onOpen)
  local currentBuffer = vim.api.nvim_get_current_buf()

  if treeView.is_visible() then
    -- If the tree view is visible but this is not the buffer, move focus to the buffer
    local treeBuffer = treeView.get_bufnr()

    if currentBuffer == treeBuffer then
      M.closeTree()

      return
    else
      treeView.focus()
    end
  else
    M.openReplacingBuffer()
  end

  if onOpen then
    onOpen(currentBuffer)
  end
end

return M
