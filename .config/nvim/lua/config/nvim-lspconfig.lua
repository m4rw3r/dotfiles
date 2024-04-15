local M = {
  "neovim/nvim-lspconfig",
  keys = {
    { "n", "<leader>d", vim.lsp.buf.definition},
    { "n", "K", vim.lsp.buf.hover},
    { "n", "<leader>k", vim.lsp.buf.signature_help},
    { "n", "<leader>D", vim.lsp.buf.type_definition},
    { "n", "<leader>e", vim.diagnostic.open_float},
  },
}

function M.config()
  local lsp = require("lspconfig")

  lsp.psalm.setup({
    cmd = {"x", "psalm", "--language-server"},
    flags = { debounce_text_changes = 150 },
    root_dir = function()
      return vim.fs.dirname(vim.fs.find({ "composer.json" }, { upward = true })[1])
    end,
  })

  -- TODO: FlowJS LSP
  -- TODO: GraphQL LSP
  -- TODO: Java LSP
  -- TODO: Rust
end

return M
