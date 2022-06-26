local util = require("config.util")

local M = {
  keymap = {},
  keys = {},
  cmd = { "Telescope" },
}

util.addKey(M, "", "<C-p>",
  function() require('telescope.builtin').find_files() end,
  { desc = "Fuzzy find file in project" }
)
util.addKey(M, "", "<M-p>",
  function() require('telescope.builtin').find_files({ no_ignore = true }) end,
  { desc = "Fuzzy find file in project, ignoring any ignores" }
)
util.addKey(M, "", "<leader>f",
  function() require('telescope.builtin').live_grep() end,
  { desc = "Fuzzy search files in project" }
)

function M.config()
  local telescope = require("telescope")
  local actions = require("telescope.actions")

  telescope.setup({
    mappings = {
      i = {
        ["<C-c>"] = actions.close,
      },
      n = {
        ["<C-c>"] = actions.close,
      },
    },
  })

  telescope.load_extension("fzy_native")

  util.registerModuleKeymap(M)
end

return M
