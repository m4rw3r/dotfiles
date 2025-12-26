--[[
Fast completion plugin.

nvim-cmp has some issues with old overlay integration as well as speed.
]]

---@type PaqPlusPlugin
local M = {
  "saghen/blink.cmp",
  -- We have to use a specific tag to get a precompiled rust binary
  branch = "v1.7.0",
  pin = true,
  requires = {
    "xzbdmw/colorful-menu.nvim",
    "Kaiser-Yang/blink-cmp-avante",
  },
}

--- Returns true if the current cursor position has word-characters to the left.
---@return boolean
local function has_words_before()
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))

  return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
end

function M.config()
  local blink = require("blink.cmp")
  local colorfulMenu = require("colorful-menu")

  blink.setup({
    sources = {
      default = { "avante", "lsp", "path", "snippets", "buffer", },
      providers = {
        avante = {
          module = "blink-cmp-avante",
          name = "Avante",
          opts = {
            -- options for blink-cmp-avante
          }
        }
      },
    },
    keymap = {
      preset = "none",

      ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
      ["<C-e>"] = { "hide" },
      ["<Up>"] = { "select_prev", "fallback" },
      ["<Down>"] = { "select_next", "fallback" },
      ["<Tab>"] = {
        function(cmp)
          if has_words_before() then
            return cmp.insert_next()
          end
        end,
        "fallback"
      },
      ["<S-Tab>"] = {
        function(cmp)
          if has_words_before() then
            return cmp.insert_prev()
          end
        end,
        "fallback"
      },
      ["<CR>"] = {
        function(cmp)
          if cmp.is_visible() and cmp.get_selected_item() then
            return cmp.accept()
          end
        end,
        "fallback",
      },
    },
    completion = {
      list = {
        selection = {
          auto_insert = false,
          preselect = false
        },
      },
      menu = {
        draw = {
          -- We don't need label_description now because label and
          -- label_description are already combined together in label by
          -- colorful-menu.nvim.
          columns = { { "kind_icon" }, { "label", gap = 1 } },
          components = {
            label = {
              text = function(ctx)
                return colorfulMenu.blink_components_text(ctx)
              end,
              highlight = function(ctx)
                return colorfulMenu.blink_components_highlight(ctx)
              end,
            },
          },
        },
      },
    },
  })
end

return M
