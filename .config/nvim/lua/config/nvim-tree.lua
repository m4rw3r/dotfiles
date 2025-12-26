-- Lazy loaded, make sure to only load the module in callbacks

---@type PaqPlusPlugin
local M = {
  "nvim-tree/nvim-tree.lua",
  branch = "master",
  requires = {
    "nvim-tree/nvim-web-devicons",
  },
  -- Lazy load on the custom tree-display commands
  opt = true,
  keys = {
    {
      "",
      "<Leader><Tab>",
      function()
        local tree = require("nvim-tree-vinegar")

        tree.actions.toggle(tree.restoreTabState)
      end,
      { desc = "Toggles the nvim-tree in the current window/pane" },
    },
    {
      "",
      "<Leader>r",
      function()
        local tree = require("nvim-tree-vinegar")

        tree.actions.toggle(tree.findBuffer)
      end,
      { desc = "Toggles the nvim-tree in the current window/pane, expanding to and highlighting the current file" },
    },
  },
}

local function on_attach(bufnr)
  local api = require("nvim-tree.api")
  local vinegar = require("nvim-tree-vinegar")

  local function opts(desc)
    return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
  end

  -- Edit in place since we use vinegar-like

  vim.keymap.set("n", "<C-w>", vinegar.actions.closeTree, opts("Close"))
  vim.keymap.set("n", "<Leader>w", vinegar.actions.closeTree, opts("Close"))

  vim.keymap.set("n", "<CR>", vinegar.actions.editInPlace, opts("Open: In Place"))
  vim.keymap.set("n", "o", vinegar.actions.editInPlace, opts("Open: In Place"))
  vim.keymap.set("n", "s", vinegar.actions.openFile(vinegar.open.split), opts("Open: Horizontal Split"))
  vim.keymap.set("n", "i", vinegar.actions.openFile(vinegar.open.vsplit), opts("Open: Vertical Split"))

  vim.keymap.set("n", "I", api.tree.toggle_gitignore_filter, opts("Toggle Git Ignore"))
  vim.keymap.set("n", "H", api.tree.toggle_hidden_filter, opts("Toggle Dotfiles"))
  vim.keymap.set("n", "R", api.tree.reload, opts("Refresh"))

  vim.keymap.set("n", "U", api.tree.change_root_to_parent, opts("Up"))
  vim.keymap.set("n", "K", api.node.navigate.sibling.first, opts("First Sibling"))
  vim.keymap.set("n", "J", api.node.navigate.sibling.last, opts("Last Sibling"))
  vim.keymap.set("n", "<", api.node.navigate.sibling.prev, opts("Previous Sibling"))
  vim.keymap.set("n", ">", api.node.navigate.sibling.next, opts("Next Sibling"))

  vim.keymap.set("n", "x", api.node.navigate.parent_close, opts("Close Directory"))
  vim.keymap.set("n", "?", api.tree.toggle_help, opts("Help"))
  vim.keymap.set("n", "C", vinegar.actions.changeDir, opts("Changes the current directory to the selected directory, or the directory of the selected file"))

  vim.keymap.set("n", "a", api.fs.create, opts("Create"))
  vim.keymap.set("n", "d", api.fs.remove, opts("Delete"))
  vim.keymap.set("n", "r", api.fs.rename, opts("Rename"))
end

function M.config()
  local tree = require("nvim-tree-vinegar")

  tree.setup({
    on_attach = on_attach,
    prefer_startup_root = true,
    git = {
      enable = true,
      timeout = 3000,
      ignore = true,
    },
    filters = {
      custom = {
        "^\\.git$",
        "^\\.DS_Store$",
        "^Thumbs.db$",
      },
    },
    view = {
      relativenumber = true,
      number = true,
      signcolumn = "auto",
    },
  })
end

return M
