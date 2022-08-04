-- Lazy loaded, make sure to only load the module in callbacks

local M = {
  "kyazdani42/nvim-tree.lua",
  tag = "nightly",
  requires = {
    "lkyazdani42/nvim-web-devicons",
  },
  wants = {
    "nvim-tree.lua",
    "nvim-web-devicons",
  },
  -- Lazy load on the custom tree-display commands
  opt = true,
  keys = {
    {
      "",
      "<Leader><Tab>",
      function()
        local tree = require("nvim-tree-vinegar")

        tree.actions.toggle(tree.restoreTabState)
      end,
      { desc = "Toggles the nvim-tree in the current window/pane" },
    },
    {
      "",
      "<Leader>r",
      function()
        local tree = require("nvim-tree-vinegar")

        tree.actions.toggle(tree.findBuffer)
      end,
      { desc = "Toggles the nvim-tree in the current window/pane, expanding to and highlighting the current file" },
    },
  },
}

function M.config()
  local tree = require("nvim-tree-vinegar")

  tree.setup({
    prefer_startup_root = true,
    git = {
      enable = true,
      timeout = 400,
      ignore = true,
    },
    filters = {
      custom = {
        "^\\.git$",
        "^\\.DS_Store$",
        "^Thumbs.db$",
      },
    },
    view = {
      relativenumber = true,
      number = true,
      signcolumn = "number",
      mappings = {
        custom_only = true,
        list = {
          -- Edit in place since we use vinegar-like
          {
            key = {"<CR>", "o"},
            action = "edit_in_place",
            action_cb = tree.actions.editInPlace,
            desc = "Open a file or directory, replacing the explorer buffer",
          },
          -- Recreate the close-window mappings
          {
            key = {"<C-w>", "<Leader>w"},
            -- We have to have both an action and an
            -- action_cb, the action_cb will replace any
            -- default action
            action = "close",
            action_cb = tree.actions.closeTree,
            desc = "Close and return to the previous buffer",
          },
          -- Visibility
          { key = "I", action = "toggle_git_ignored", desc = "Toggle showing gitignored files" },
          { key = "H", action = "toggle_dotfiles", desc = "Toggle showing hidden files" },
          -- NERDTree like bindings
          { key = "s", action = "split", action_cb = tree.actions.openFile(tree.open.split), desc = "Open the given file in a horizontal split" },
          { key = "i", action = "vsplit", action_cb = tree.actions.openFile(tree.open.vsplit), desc = "Open the given file in a vertical split" },
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
            action_cb = tree.actions.changeDir,
            desc = "Changes the current directory to the selected directory, or the directory of the selected file",
          },
          -- File management bindings
          { key = "a", action = "create", desc = "Create file/directory, directories end in '/'" },
          { key = "d", action = "remove", desc = "Delete file/directory" },
          { key = "r", action = "rename", desc = "Rename file/directory" },
        },
      },
    },
  })
end

return M
