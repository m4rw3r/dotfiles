-- TODO: Separate config from code?

local M = {
  indents = {
    cabal = { expandtab = true },
    haskell = { expandtab = true },
    html = { autoindent = false },
    javascript = { expandtab = true, indent = 2, trim = true, autoindent = false },
    json = { expandtab = true, indent = 2, trim = true },
    lua = { indent = 2, expandtab = true, trim = true },
    php = { expandtab = true, trim = true, autoindent = false },
    python = { expandtab = true },
    ruby = { indent = 2 },
    rust = { expandtab = true, trim = true },
    sql = { autoindent = false },
    xml = { expandtab = true, indent = 2, trim = true },
    yaml = { indent = 2 },
  },
  syntax = {
    "bash",
    "c",
    "dockerfile",
    "dot",
    "graphql",
    "haskell",
    "html",
    "java",
    "javascript",
    "json",
    "latex",
    "lua",
    "php",
    "python",
    "ruby",
    "rust",
    "toml",
    "vim",
    "yaml",
  },
}

local function stripTrailingWhitespace()
  local c = vim.api.nvim_win_get_cursor(0)

  vim.cmd("%s/\\s\\+$//e")

  vim.api.nvim_win_set_cursor(0, c)
end
vim.api.nvim_create_user_command(
  "StripTrailingWhitespace",
  stripTrailingWhitespace,
  {
    desc = "Stripts the trailing whitespace from the current buffer",
  }
)

function M.registerIndentAutogroup()
  local indentgroup = vim.api.nvim_create_augroup("indent", {})

  for filetype, config in pairs(M.indents) do
    setmetatable(config, { __index = {
      indent = nil,
      expandtab = false,
      trim = false,
      autoindent = true,
    } } )

    vim.api.nvim_create_autocmd(
      {"FileType"},
      {
        pattern = filetype,
        group = indentgroup,
        callback = function()
          if config.indent then
            vim.opt_local.shiftwidth = config.indent
            vim.opt_local.tabstop = config.indent
          end

          if config.expandtab then
            vim.opt_local.expandtab = true
          end

          if config.trim then
            vim.api.nvim_create_autocmd(
              {"BufWritePre"},
              {
                callback = stripTrailingWhitespace,
                desc = "Trim trailing whitespace on save",
              }
            )
          end

          if not config.autoindent then
            vim.opt_local.indentexpr = ""
          end
        end
      }
    )
  end
end

return M
