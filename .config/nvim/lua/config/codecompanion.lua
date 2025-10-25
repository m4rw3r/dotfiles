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
      http = {
        devstral = function()
          return require("codecompanion.adapters").extend("ollama", {
            name = "devstral",
            schema = {
              model = {
                default = "devstral:24b",
              },
            },
          })
        end,
        qwen3 = function()
          return require("codecompanion.adapters").extend("ollama", {
            name = "qwen3",
            env = {
              -- url = "http://4090.m4rw3r.dev:11434",
              -- url = "http://10.42.40.167:11434",
              url = "http://10.42.40.71:11434",
            },
            schema = {
              model = {
                -- This fits in a 4090 nicely
                -- default = "qwen3:32b",
                default = "qwen3-coder:30b",
              },
              keep_alive = {
                default = "15m"
              },
            },
          })
        end,
      },
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
