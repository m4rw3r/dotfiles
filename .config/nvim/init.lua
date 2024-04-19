-- Use the experimental bytecode cache
vim.loader.enable()

-- Configuration
local indent = 4
local XDG_DATA_HOME = vim.env.XDG_DATA_HOME or vim.env.HOME .. "/.local/share"
local backupdir = XDG_DATA_HOME .. "/nvim/backup//"
local swapdir = XDG_DATA_HOME .. "/nvim/swap//"
local undodir = XDG_DATA_HOME .. "/nvim/swap/"
local viewdir = XDG_DATA_HOME .. "/nvim/view//"

-- Skip some unused built-in plugins
vim.g.loaded_zipPlugin = true
vim.g.loaded_tarPlugin = true
-- We do not use netrw
vim.g.loaded_netrw = true
vim.g.loaded_netrwSettings = true
vim.g.loaded_netrwPlugin = true
vim.g.loaded_netrwFileHandlers = true
-- Or advanced matching
vim.g.loaded_matchit = true
vim.g.loaded_remote_plugins = true
vim.g.loaded_2html_plugin = true
-- Skip FZF since we use FZY
vim.g.loaded_fzf = true
-- Do not load old filetype.vim, use the new filetype.lua
vim.g.do_filetype_lua = true
vim.g.did_load_filetypes = false

local paqPlus = require("paq-plus")

paqPlus.bootstrap({
  before = function()
    -- Create required folders
    for _, d in pairs({ backupdir, swapdir, undodir, viewdir }) do
      vim.fn.system("mkdir -p '" .. d .. "'")
    end
  end
})
paqPlus.init(function(use)
  use({ "savq/paq-nvim" })

  -- Lua bytecode cache to speed up launching
  use({ "tweekmonster/startuptime.vim" })

  -- Utilities
  --
  -- Automatically sets the working-directory to the detected project root if any
  use({ "ygm2/rooter.nvim" })
  -- Fuzzy finder for files, and in files
  use(require("config.telescope"))
  use({ "lewis6991/gitsigns.nvim" })
  use({ "gpanders/editorconfig.nvim" })

  -- UI
  --
  -- Status-line replacement
  use({
    "nvim-lualine/lualine.nvim",
    requires = { "kyazdani42/nvim-web-devicons" },
    config = function()
      local lualine = require("lualine")

      lualine.setup({
        options = {
          theme = "auto",
        },
        sections = {
          lualine_a = {"mode"},
          lualine_b = {"branch"},
          lualine_c = {
            { "filename", path = 1 },
          },
          lualine_x = {"encoding", "fileformat", "filetype"},
          lualine_y = {"progress"},
          lualine_z = {"location"},
        },
      })
    end
  })
  -- Rainbow parenthesis using treesitter
  use({ "HiPhish/rainbow-delimiters.nvim" })
  -- Show colors like #f0f
  -- TODO: no longer works
  use({
    "norcalli/nvim-colorizer.lua",
    config = function()
      local colorizer = require("colorizer")

      colorizer.setup()
    end
  })
  use(require("config.nvim-tree"))

  -- Language integration
  --
  -- LSP
  use(require("config.nvim-lspconfig"))
  use(require("config.nvim-cmp"))
  use(require("config.treesitter"))
  use({
    "folke/trouble.nvim",
    requires = { "kyazdani42/nvim-web-devicons" },
    config = function()
      require("trouble").setup({})
    end
  })

  -- Colorschemes
  use({
    "RRethy/nvim-base16",
    config = function()
      vim.cmd("colorscheme base16-tomorrow-night")
      -- Shortcuts to swap the theme
      vim.api.nvim_create_user_command(
        "Dark",
        "colorscheme base16-tomorrow-night",
        { desc = "Switch colorscheme to dark" }
      )
      vim.api.nvim_create_user_command(
        "Light",
        "colorscheme base16-tomorrow",
        { desc = "Switch colorscheme to light" }
      )
    end
  })
end)

-- Files
vim.opt.fileencoding = "utf-8"
vim.opt.fileencodings = "ucs-bom,utf-8"
vim.opt.binary = true -- Allow binary file ediding without mangling to UTF-8
vim.opt.eol = false -- Do not append linebreak at EOF
vim.opt.backup = true -- Backup files
vim.opt.undofile = true -- Save undo in files
-- We have to replace the list to avoid having backups in the current folder
vim.opt.backupdir = { backupdir }
vim.opt.directory = { swapdir }
vim.opt.undodir = undodir
vim.opt.viewdir = viewdir

-- Tabs and indent
vim.opt.tabstop = indent
vim.opt.shiftwidth = indent
vim.opt.foldenable = false

-- UI
vim.opt.showcmd = true -- Show incomplete commands
vim.opt.hidden = true -- Allow buffer-switching without save
vim.opt.timeoutlen = 500 -- Quicker timeout on commands
vim.opt.ttimeoutlen = 10 -- Quicker timeout on key-combinations
vim.opt.list = true -- Show tabs, line-breaks, trailing spaces, end of line
vim.opt.listchars = { eol = "¬", nbsp = "¬" , tab = "▸ ", trail = "·" , precedes = "«", extends = "»" }
vim.opt.display:append("uhex") -- Show invalid unicode characters as hex
vim.opt.relativenumber = true -- Relative line-numbers in the gutter
vim.opt.number = true -- Show line number on the current line
vim.opt.cursorline = true -- Highlight the current line
vim.opt.signcolumn = "number" -- Show signs in the number column
vim.opt.splitbelow = true -- Split pane below by default
vim.opt.splitright = true -- Split pane to the right by default
vim.opt.scrolloff = 5 -- Always allow 5 empty "lines" beyond start and end of file

vim.diagnostic.config({
  virtual_text = false,
  signs = true,
  float = {
    border = "single",
    format = function(diagnostic)
      return string.format(
        "%s (%s) [%s]",
        diagnostic.message,
        diagnostic.source,
        diagnostic.code or diagnostic.user_data.lsp.code
      )
    end,
  },
})

-- Search
vim.opt.showmatch = true
vim.opt.ignorecase = true -- Ignore case for search
vim.opt.smartcase = true -- Ignore case by default, but swap to case-sensitive
                         -- search as soon as at least one uppercase letter is used

-- Font and Color
vim.opt.termguicolors = true -- Enable 24-bit RGB in the terminal UI

-- Keybindings
vim.g.mapleader = " "
vim.opt.omnifunc = "v:lua.vim.lsp.omnifunc"

vim.keymap.set("i", "jj", "<Esc>", { silent = true }) -- Quick exit of insert-mode
vim.keymap.set("i", "<Left>", "<NOP>", { silent = true }) -- Do not allow arrows while editing
vim.keymap.set("i", "<Down>", "<NOP>", { silent = true })
vim.keymap.set("i", "<Up>", "<NOP>", { silent = true })
vim.keymap.set("i", "<Right>", "<NOP>", { silent = true })
vim.keymap.set("n", "j", "gj", { noremap = false, silent = true }) -- Visual navigation using hjkl even over multiple lines
vim.keymap.set("n", "k", "gk", { noremap = false, silent = true })
vim.keymap.set("v", "j", "gj", { noremap = false, silent = true })
vim.keymap.set("v", "k", "gk", { noremap = false, silent = true })
vim.keymap.set("n", "<F3>", "<cmd>noh<CR>", { silent = true }) -- Toggle search highlight
vim.keymap.set("", "<Leader>j", "<cmd>bnext<CR>", { noremap = false }) -- Navigate between buffers using Leader j/k
vim.keymap.set("", "<Leader>k", "<cmd>bprevious<CR>", { noremap = false })
vim.keymap.set("", "<Leader>w", "<cmd>bp|bd #<CR>", { noremap = false }) -- Close the current buffer with leader w
vim.keymap.set("n", "<Leader>e", vim.diagnostic.open_float, { noremap = false })
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { noremap = false })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { noremap = false })
vim.keymap.set("n", "<Leader>v", "<c-v>", { noremap = false }) -- Make sure we can do vertical selection in Windows Terminal

local languages = require("languages")

languages.registerIndentAutogroup(require("config.languages").indents)

local kitty = require("kitty")

-- Easier window pane navigation using Ctrl + hjkl, with Kitty integration
vim.keymap.set("", "<C-h>", kitty.navigate("h", "left"), { silent = false, noremap = true })
vim.keymap.set("", "<C-j>", kitty.navigate("j", "bottom"), { silent = false, noremap = true })
vim.keymap.set("", "<C-k>", kitty.navigate("k", "top"), { silent = false, noremap = true })
vim.keymap.set("", "<C-l>", kitty.navigate("l", "right"), { silent = false, noremap = true })