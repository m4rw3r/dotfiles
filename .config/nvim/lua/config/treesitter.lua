local languages = require("config.languages")

---@type PaqPlusPlugin
local M = {
  "nvim-treesitter/nvim-treesitter",
}

vim.api.nvim_create_user_command(
  "UserTSUpdate",
  "TSUpdate " .. table.concat(languages.syntax, " "),
  {
    desc = "Updates/Installs all user-requested languages in Treesitter",
  }
)

function M.config()
  local treesitter_configs = require("nvim-treesitter.configs")

  vim.treesitter.language.register("markdown", "codecompanion")

  treesitter_configs.setup({
    highlight = {
      enable = true,
    },
    indent = {
      disable = { "php" },
      enable = true,
    },
  })
end

-- Run on install/update
function M.build()
  -- Make sure to configure ourselves before we run
  M.config()

  -- Update instead of install, since then it will install it if it is missing
  vim.cmd("UserTSUpdate")
end

return M
