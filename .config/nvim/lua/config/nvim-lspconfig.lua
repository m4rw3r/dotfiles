local M = {
  "neovim/nvim-lspconfig",
  keys = {
    { "n", "<leader>d", vim.lsp.buf.definition },
    { "n", "<leader>D", vim.lsp.buf.type_definition },
    { "n", "K", vim.lsp.buf.hover },
    { "n", "<leader>K", vim.lsp.buf.signature_help },
    { "n", "<leader>e", vim.diagnostic.open_float },
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

  lsp.rust_analyzer.setup({})
  lsp.tsserver.setup({
    filetypes = { "typescript", "typescriptreact", "typescript.tsx" },
    cmd = { "typescript-language-server", "--stdio" }
  })

  -- TODO: GraphQL LSP
  -- TODO: Java LSP
end

return M
