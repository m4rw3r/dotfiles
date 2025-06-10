---@type PaqPlusPlugin
local M = {
  "nvim-telescope/telescope.nvim",
  requires = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope-fzy-native.nvim",
  },
  opt = true,
  -- Important that this require does not immediately perform further
  -- requires, but that it is deferred to the config function:
  keys = {
    {
      "",
      "<C-p>",
      function() require('telescope.builtin').find_files() end,
      { desc = "Fuzzy find file in project" }
    },
    {
      "",
      "<M-p>",
      function() require('telescope.builtin').find_files({ no_ignore = true }) end,
      { desc = "Fuzzy find file in project, ignoring any ignores" }
    },
    {
      "",
      "<leader>f",
      function() require('telescope.builtin').live_grep() end,
      { desc = "Fuzzy search files in project" }
    },
  },
  cmd = {
    "Telescope",
  },
}

function M.config()
  local telescope = require("telescope")
  local actions = require("telescope.actions")

  telescope.setup({
    defaults = {
      mappings = {
        i = {
          ["<C-c>"] = actions.close,
          ["<C-j>"] = actions.cycle_history_next,
          ["<C-k>"] = actions.cycle_history_prev,
        },
        n = {
          ["<C-c>"] = actions.close,
          ["<C-j>"] = actions.cycle_history_next,
          ["<C-k>"] = actions.cycle_history_prev,
        },
      },
    },
    pickers  = {
      find_files = {
        hidden = true,
        -- Hide git
        file_ignore_patterns = {".git"}
      },
    },
  })

  telescope.load_extension("fzy_native")
end

return M
