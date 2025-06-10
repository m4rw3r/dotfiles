---AI Coding tool
---@type PaqPlusPlugin
local M = {
  "olimorris/codecompanion.nvim",
  requires = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "j-hui/fidget.nvim",
    "nvim-telescope/telescope.nvim",
  },
  keys = {
    {
      "",
      "<Leader>c",
      "<cmd>:CodeCompanionChat Toggle<cr>", { noremap = true, silent = true, desc = "Toggle CodeCompanion Chat frame" },
    },
  },
}

function M.config()
  -- LuaLS finds some extension-files, causing the module to appear as a function
  local codecompanion = require("codecompanion") --[[@as CodeCompanion]]

  codecompanion.setup({
    strategies = {
      chat = {
        adapter = "qwen3",
        keymaps = {
          -- Send prompt with Ctrl + Enter
          send = {
            modes = {
              n = "<C-s>",
              i = "<C-s>",
            },
            opts = {},
          },
        },
      },
    },
    adapters = {
      qwen3 = function()
        return require("codecompanion.adapters").extend("ollama", {
          name = "qwen3",
          schema = {
            model = {
              default = "qwen3:32b",
            },
          },
        })
      end
    },
  })

  vim.api.nvim_create_autocmd("User", {
    pattern = "CodeCompanionChatCreated",
    callback = function(request)
      -- Manually start treesitter to get embedded code highlights
      vim.treesitter.start()
    end,
  })
end

return M
