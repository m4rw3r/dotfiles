--AI Coding tool
--@type PaqPlusPlugin
local M = {
  "yetone/avante.nvim",
  requires = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    --- The below dependencies are optional,
    -- "nvim-mini/mini.pick", -- for file_selector provider mini.pick
    -- "nvim-telescope/telescope.nvim", -- for file_selector provider telescope
    -- "hrsh7th/nvim-cmp", -- autocompletion for avante commands and mentions
    -- "ibhagwan/fzf-lua", -- for file_selector provider fzf
    -- "stevearc/dressing.nvim", -- for input provider dressing
    "folke/snacks.nvim", -- for input provider snacks
    -- "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
    -- "folke/snacks.nvim", -- Input provider
    -- Maybe instead of the other devicons pack
    "nvim-tree/nvim-web-devicons",
  }
}

local loaders = {
  moons = {
    -- "   ", -- odd with it completely disappearing
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    -- "  ", -- looks weird
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    ------
    -- "  ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    -- "  ", -- looks weird
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    -- "  ",
    -- "   ", -- odd with it completely disappearing
  },
  moons_edge = {
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
  },
  squares = {
    "🮠", "🮧", "🮬", "🮮",
    "🮡", "🮥", "🮪", "🮮",
    "🮣", "🮦", "🮫", "🮮",
    "🮢", "🮤", "🮭", "🮮",
  },
  sweep = {
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
  },
  spinner = {
    " ",
    " ",
    " ",
    " ",
    " ",
    " ",
  },
};

function M.config()
  local avante = require("avante")

  avante.setup({
    input = {
      provider = "snacks",
    },
    file_selector = {
      provider = "snacks",
    },
    provider = "llama-swap",
    auto_suggestions_provider = false,
    providers = {
      ["llama-swap"] = {
        __inherited_from = "openai",
        url = vim.env.LLAMA_SWAP_URL or "http://10.42.40.71:8989",
        api_key_name = "",
        endpoint = vim.env.LLAMA_SWAP_URL or "http://10.42.40.71:8989/v1",
        model = "Qwen3-Coder",
        model_names = {
          "Devstral-Small",
          "Devstral-Small-2-24B",
          "Qwen3-Coder",
          "Qwen3",
        },
      },
    },
    behaviour = {
      auto_approve_tool_permissions = false,
    },
    mappings = {
      submit = {
        normal = "<C-s>",
        insert = "<C-s>",
      },
    },
    windows = {
      spinner = {
        generating = loaders.spinner,
        thinking = loaders.sweep,
      },
    },
    selector = {
      provider = "snacks",
    },
    slash_commands = {
      {
        name = "history",
        description = "Shows the Avante Chat history",
        details = "Allows to swap to different chats",
        callback = function()
          vim.cmd("AvanteHistory")
        end
      },
    },
    -- TODO: Agent-Client-Protocol (ACP)?
    -- TODO: Enable RAG Service
  })
end

function M.build()
  vim.cmd("make")

  M.config()
end

return M
