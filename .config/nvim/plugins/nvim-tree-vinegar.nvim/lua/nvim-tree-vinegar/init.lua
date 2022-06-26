-- This is a major addition to better support smooth vinegar-like
-- window-replacement with opening files in splits, then restoring
-- the previous window contents.

local M = {}

local tree = require("nvim-tree")
local treeActionFindFile = require("nvim-tree.actions.find-file")
local treeView = require("nvim-tree.view")

local actions = require("nvim-tree-vinegar.actions")
local open = require("nvim-tree-vinegar.open")
local util = require("nvim-tree-vinegar.util")

M.actions = actions
M.open = open

local function registerAutocmds()
  local group = vim.api.nvim_create_augroup("NvimTree", { clear = false })
  -- Save the tab state when moving focus so we can restore it when
  -- nvim-tree is focused again, this is also triggered when splitting
  vim.api.nvim_create_autocmd({"WinLeave"}, {
    pattern = {"NvimTree*"},
    group = group,
    callback = util.saveTabState,
  })
end

function M.restoreTabState()
  treeView.restore_tab_state()
end

local defaultMappings = {
  -- Edit in place since we use vinegar-like
  {
    key = {"<CR>", "o"},
    action = "edit_in_place",
    action_cb = M.actions.editInPlace,
    desc = "Open a file or directory, replacing the explorer buffer",
  },
  -- Recreate the close-window mappings
  {
    key = {"<C-w>", "<Leader>w"},
    -- We have to have both an action and an
    -- action_cb, the action_cb will replace any
    -- default action
    action = "close",
    action_cb = M.actions.closeTree,
    desc = "Close and return to the previous buffer",
  },
  -- Visibility
  { key = "I", action = "toggle_git_ignored", desc = "Toggle showing gitignored files" },
  { key = "H", action = "toggle_dotfiles", desc = "Toggle showing hidden files" },
  -- NERDTree like bindings
  { key = "s", action = "split", action_cb = M.actions.openFile(M.open.split), desc = "Open the given file in a horizontal split" },
  { key = "i", action = "vsplit", action_cb = M.actions.openFile(M.open.vsplit), desc = "Open the given file in a vertical split" },
  { key = "p", action = "parent", desc = "Go to the parent directory" },
  { key = "K", action = "first_sibling", desc = "Go to the first sibling" },
  { key = "J", action = "last_sibling", desc = "Go to the last sibling" },
  { key = "U", action = "dir_up", desc = "Navigate to the parent of the current file/directory" },
  { key = "<", action = "prev_sibling", desc = "Go to previous siblilng" },
  { key = ">", action = "next_sibling", desc = "Go to next sibling" },
  { key = "R", action = "refresh", desc = "Refresh the directory tree" },
  { key = "x", action = "close_node", desc = "Close the current directory or parent" },
  { key = "?", action = "toggle_help", desc = "Toggle help" },
  {
    key = "C",
    action = "change_dir",
    action_cb = M.actions.changeDir,
    desc = "Changes the current directory to the selected directory, or the directory of the selected file",
  },
  -- File management bindings
  { key = "a", action = "create", desc = "Create file/directory, directories end in '/'" },
  { key = "d", action = "remove", desc = "Delete file/directory" },
  { key = "r", action = "rename", desc = "Rename file/directory" },
}

local function mergeMappings(old, new)
  local newKeys = {}
  local removedKeys = {}
  local newMappings = vim.deepcopy(new)

  for _, map in pairs(new) do
    if type(map.key) == "table" then
      for _, key in pairs(map.key) do
        table.insert(newKeys, key)
        if is_empty(map.action) then
          table.insert(removedKeys, key)
        end
      end
    else
      table.insert(newKeys, map.key)
      if is_empty(map.action) then
        table.insert(removedKeys, map.key)
      end
    end
  end

  for _, map in pairs(old) do
    if type(map.key) == "table" then
      local keys = {}

      for _, key in pairs(map.key) do
        if not vim.tbl_contains(newKeys, key) and not vim.tbl_contains(removedKeys, key) then
          table.insert(keys, key)
        end
      end

      if not vim.tbl_isempty(keys) then
        table.insert(newMappings, vim.tbl_extend("keep", {
          key = keys,
        }, map))
      end
    else
      table.insert(newKeys, map.key)
      if not vim.tbl_contains(newKeys, key) and not vim.tbl_contains(removedKeys, key) then
        table.insert(newMappings, map)
      end
    end
  end

  return newMappings
end

function M.setup(opts)
  local mappings = defaultMappings

  if opts and opts.view and opts.view.mappings then
    if not opts.view.mappings.custom_only then
      mappings = mergeMappings(mappings, opts.view.mappings)
    else
      mappings = opts.view.mappings
    end
  end

  local newOpts = vim.tbl_extend("keep", {
    view = vim.tbl_extend("keep", {
      mappings = {
        custom_only = true,
        list = mappings,
      },
    }, opts.view or {}),
  }, opts or {})

  local fixHeight = false

  if opts.fix_window_size then
    fixHeight = true
  end

  opts.fix_window_size = nil

  tree.setup(newOpts)

  if not fixHeight then
    -- By removing the window width/height fixing any splits will split the current browser
    treeView.View.winopts.winfixwidth = nil
    treeView.View.winopts.winfixheight = nil
  end

  -- TODO: Update the commands?
  -- TODO: Provide both split and non-split options?

  registerAutocmds()
end

function M.findBuffer(buffer)
  local bufname = vim.api.nvim_buf_get_name(buffer)
  -- Only search for the current file if we have a saved file open
  if bufname ~= "" and vim.loop.fs_stat(bufname) ~= nil then
    treeActionFindFile.fn(bufname)
  end
end

return M
