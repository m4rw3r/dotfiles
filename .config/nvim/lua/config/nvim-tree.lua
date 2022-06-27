-- Lazy loaded, make sure to only load the module in callbacks

local M = {
  "./plugins/nvim-tree-vinegar.nvim",
  requires = {
    {
      "kyazdani42/nvim-tree.lua",
      tag = "nightly",
    },
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
    },
  })
end

return M
