-- This is a major addition to better support smooth vinegar-like
-- window-replacement with opening files in splits, then restoring
-- the previous window contents.

local M = {}

local tree = require("nvim-tree")
local treeApi = require("nvim-tree.api")

local treeCore = require("nvim-tree.core")
local treeUtils = require("nvim-tree.utils")
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
    callback = util.save_tab_state,
  })
end

function M.restoreTabState()
  treeView.restore_tab_state()
end

local defaultOptions = {
  view = {
    mappings = {
      list = {
        -- Edit in place since we use vinegar-like
        {
          key = {"<CR>", "o"},
          action = "edit_in_place",
          action_cb = M.actions.editInPlace,
          desc = "Open a file or directory, replacing the explorer buffer",
        },
      },
    },
  },
}

function M.setup(opts)
  opts = opts or vim.deepcopy(defaultOptions)

  if opts.fix_window_size then
    util.setFixHeight(true)
  end

  opts.fix_window_size = nil

  tree.setup(opts)

  -- TODO: Update the commands?
  -- TODO: Provide both split and non-split options?

  registerAutocmds()
end

function M.findBuffer(buffer)
  local bufname = vim.api.nvim_buf_get_name(buffer)
  -- Only search for the current file if we have a saved file open
  if bufname ~= "" and vim.uv.fs_stat(bufname) ~= nil then
    local cwd = treeUtils.path_remove_trailing(treeCore.get_cwd() or "")

    if string.find(bufname, cwd, 0, true) ~= 1 then
      -- If the buffer is above the current working directory change to it to the first common folder
      repeat
        cwd = vim.fn.fnamemodify(treeUtils.path_remove_trailing(cwd), ":h")
      until string.find(bufname, cwd, 0, true) == 1

      -- TODO: cd vim?
      treeCore.init(cwd, "nvim-tree-vinegar.findBuffer")
      util.drawTree()
    end

    treeApi.tree.find_file(bufname)
  end
end

return M
