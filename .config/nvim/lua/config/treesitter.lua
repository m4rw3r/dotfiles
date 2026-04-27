local languages = require("config.languages")

---@type PaqPlusPlugin
local M = {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
}

function M.install_all()
  local treesitter = require("nvim-treesitter")

  treesitter.install(languages.syntax)
end

vim.api.nvim_create_user_command(
  "UserTSUpdate",
  M.install_all,
  {
    desc = "Updates/Installs all user-requested languages in Treesitter",
  }
)

function M.config()
  local treesitter = require("nvim-treesitter")

  vim.treesitter.language.register("markdown", "codecompanion")

  treesitter.setup({
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
  M.install_all()
end

return M
