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
  wants = {
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
  local codecompanion = require("codecompanion")

  codecompanion.setup({
    strategies = {
      chat = {
        adapter = "qwen3",
        keymaps = {
          -- Send prompt with Ctrl + Enter
          send = {
            modes = {
              n = "<C-CR>",
              i = "<C-CR>",
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
