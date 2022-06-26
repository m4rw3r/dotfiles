local util = require("config.util")

local M = {
  keymap = {},
  keys = {},
  cmd = {
    "UserToggleTree",
    "UserToggleTreeFind",
  },
}

util.addKey(M, "", "<Leader><Tab>",
  function()
    local tree = require("nvim-tree-vinegar")

    tree.actions.toggle(tree.restoreTabState)
  end,
  { desc = "Toggles the nvim-tree in the current window/pane" }
)
util.addKey(M, "", "<Leader>r",
  function()
    local tree = require("nvim-tree-vinegar")

    tree.actions.toggle(tree.findBuffer)
  end,
  { desc = "Toggles the nvim-tree in the current window/pane, expanding to and highlighting the current file" }
)

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

  util.registerModuleKeymap(M)
end

return M
