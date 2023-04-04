
local M = {
  indents = {
    cabal = { expandtab = true },
    glsl = { expandtab = true },
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
    typescript = { expandtab = true, indent = 2, trim = true, autoindent = true },
    xml = { expandtab = true, indent = 2, trim = true },
    yaml = { expandtab = true, indent = 2 },
  },
  syntax = {
    "bash",
    "c",
    "dockerfile",
    "dot",
    "glsl",
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
    "query",
    "ruby",
    "rust",
    "toml",
    "typescript",
    "vim",
    "yaml",
  },
}

return M
