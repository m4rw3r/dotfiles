local languages = require("languages")

local M = {}

vim.api.nvim_create_user_command(
  "UserTSUpdate",
  "TSUpdate " .. table.concat(languages.syntax, " "),
  {
    desc = "Updates/Installs all user-requested languages in Treesitter",
  }
)

function M.config()
  local treesitter_configs = require("nvim-treesitter.configs")

  treesitter_configs.setup({
    highlight = {
      enable = true,
    },
    indent = {
      disable = { "php" },
      enable = true,
    },
    rainbow = {
      enable = true,
      -- Also highlight non-bracket delimiters like html tags, boolean or
      -- table: lang -> boolean
      extended_mode = true,
    },
  })
end

function M.run()
  -- Update instead of install, since then it will install it if it is missing
  vim.cmd("UserTSUpdate")
end

return M
