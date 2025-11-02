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
        adapter = "llama-swap",
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
        opts = {
          show_defaults = false,
          show_model_choices = true,
        },
        ["llama-swap"] = function()
          return require("codecompanion.adapters").extend("openai_compatible", {
            name = "llama.cpp",
            env = {
              -- Start:
              -- G:\llaama.cpp\llama-swap.ps1
              url = "http://10.42.40.71:8989",
            },
            schema = {
              model = {
                default = "Qwen3-Yoyo-MoE",
              },
            },
          })
        end,
      },
      acp = {
        opts = {
          show_defaults = false,
        },
      }
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
