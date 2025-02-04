local M = {
    "hrsh7th/nvim-cmp",
    requires = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "L3MON4D3/LuaSnip",
    },
  }

function M.config()
  unpack = unpack or table.unpack

  local cmp = require("cmp")
  local luasnip = require("luasnip")
  local has_words_before = function()
    local line, col = unpack(vim.api.nvim_win_get_cursor(0))

    return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
  end

  cmp.setup({
    window = {
      completion = cmp.config.window.bordered(),
      documentation = cmp.config.window.bordered(),
    },
    completion = {
      -- autocomplete = false,
      completeopt = "menuone,preview,noselect",
    },
    -- Required along with noselect to not have cmp select but not insert the option on either "words<Tab>" or <C-n>
    preselect = cmp.PreselectMode.None,
    mapping = cmp.mapping.preset.insert({
      ["<C-b>"] = cmp.mapping.scroll_docs(-4),
      ["<C-f>"] = cmp.mapping.scroll_docs(4),
      ["<C-Space>"] = cmp.mapping.complete(),
      ["<C-e>"] = cmp.mapping.abort(),

--      ["<Tab>"] = cmp.mapping(function(fallback)
--        if cmp.visible() then
--          cmp.select_next_item()
--        elseif luasnip.locally_jumpable(1) then
--          luasnip.jump(1)
--        else
--          fallback()
--        end
--      end, { "i", "s" }),
--      ["<S-Tab>"] = cmp.mapping(function(fallback)
--        if cmp.visible() then
--          cmp.select_prev_item()
--        elseif luasnip.locally_jumpable(-1) then
--          luasnip.jump(-1)
--        else
--          fallback()
--        end
--      end, { "i", "s" }),
--      ['<CR>'] = cmp.mapping(function(fallback)
--        if cmp.visible() then
--          if luasnip.expandable() then
--            luasnip.expand()
--          else
--            cmp.confirm({ select = true })
--          end
--        else
--          fallback()
--        end
--      end),

      ["<Tab>"] = function(fallback)
        if cmp.visible() then
          if #cmp.get_entries() == 1 then
            cmp.confirm({ select = true })
          else
            cmp.select_next_item()
          end
        elseif has_words_before() then
          cmp.complete()

          if #cmp.get_entries() == 1 then
            cmp.confirm({ select = true })
          else
            -- "autoselect" replacement
            cmp.select_next_item({ behavior = cmp.SelectBehavior.Insert })
          end
        else
          fallback()
        end

        -- if not cmp.select_next_item() then
        --   if vim.bo.buftype ~= "prompt" and has_words_before() then
        --     cmp.complete()
        --   else
        --     fallback()
        --   end
        -- end
      end,
      ["<S-Tab>"] = function(fallback)
        if cmp.visible() then
          if #cmp.get_entries() == 1 then
            cmp.confirm({ select = true })
          else
            cmp.select_prev_item()
          end
        elseif has_words_before() then
          cmp.complete()

          if #cmp.get_entries() == 1 then
            cmp.confirm({ select = true })
          else
            -- "autoselect" replacement
            cmp.select_prev_item({ behavior = cmp.SelectBehavior.Insert })
          end
        else
          fallback()
        end

        -- if not cmp.select_prev_item() then
        --   if vim.bo.buftype ~= "prompt" and has_words_before() then
        --     cmp.complete()
        --   else
        --     fallback()
        --   end
        -- end
      end,
      -- Safe selection on enter only
      -- when something has explicitly been selected
      ["<CR>"] = cmp.mapping({
        i = function(fallback)
          if cmp.visible() and cmp.get_active_entry() then
            cmp.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = false })
          else
            fallback()
          end
        end,
        s = cmp.mapping.confirm({ select = true }),
        c = cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true }),
      }),
    }),
    sources = cmp.config.sources({
      { name = "nvim_lsp" },
      { name = "nvim_lsp_signature_help" },
    }, {
      { name = "buffer" },
    }),
    snippet = {
      expand = function(args)
        luasnip.lsp_expand(args.body)
      end,
    },
  })
end

return M
