local cmd = vim.cmd
local opt = vim.opt
local o = vim.o
local g = vim.g
local api = vim.api
local fn = vim.fn
local indent = 4
local key = vim.api.nvim_set_keymap

-- Skip built-in plugins
g.loaded_gzip = false
g.loaded_netrwPlugin = false
g.loaded_tarPlugin = false
g.loaded_zip = false
g.loaded_2html_plugin = false
g.loaded_remote_plugins = false

-- Bootstrap packer.nvim
local install_path = fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"

if fn.isdirectory(install_path) == 0 then
  fn.system({"git", "clone", "https://github.com/wbthomason/packer.nvim", install_path})
  cmd "packadd packer.nvim"
end

local packer = require("packer")

packer.startup(function(use)
	use { "wbthomason/packer.nvim" }

	-- Utilities
	--
	-- Automatically sets the working-directory to the detected project root if any
	use { "ygm2/rooter.nvim" }
	-- Fuzzy finder for files, and in files
	use {
		"nvim-telescope/telescope.nvim",
		requires = {
			{ "nvim-lua/plenary.nvim" },
			{ "nvim-telescope/telescope-fzy-native.nvim" }
		},
		config = telescope,
	}
	use { "lewis6991/gitsigns.nvim", requires = { 'nvim-lua/plenary.nvim' }}

	-- UI
	--
	-- Status-line replacement
	use { "shadmansaleh/lualine.nvim", requires = {"kyazdani42/nvim-web-devicons" }, config = lualine }
	-- Allow window navigation outside of NeoVIM when in tmux
	use { "christoomey/vim-tmux-navigator" }
	-- Rainbow parenthesis using treesitter
	use { "p00f/nvim-ts-rainbow" }
	-- Show colors
	use { "norcalli/nvim-colorizer.lua", config = colorizer }

	-- Language integration
	--
	-- LSP
	use { "neovim/nvim-lspconfig", config = lspconfig }
	use { "nvim-lua/completion-nvim" }
	use { "nvim-treesitter/nvim-treesitter", run = treesitter_after_install, config = treesitter }

	-- Colorschemes
	use { "RRethy/nvim-base16" }

	-- TODO: Plugins
	-- TODO: Tree-plugin
end)

-- Files
opt.fileencoding = "utf-8"
opt.fileencodings = "ucs-bom,utf-8"
opt.binary = true -- Allow binary file ediding without mangling to UTF-8
opt.eol = false -- Do not append linebreak at EOF
opt.backup = true -- Backup files
opt.undofile = true -- Save undo in files

-- Tabs and indent
opt.tabstop = indent
opt.shiftwidth = indent
opt.foldenable = false
-- PHP disable PIV (if we use PIV)
-- TODO: File-type specific indents

-- UI
opt.showcmd = true -- Show incomplete commands
opt.hidden = true -- Allow buffer-switching without save
opt.timeoutlen = 500 -- Quicker timeout on commands
opt.ttimeoutlen = 10 -- Quicker timeout on key-combinations
opt.list = true -- Show tabs, line-breaks, trailing spaces, end of line
opt.listchars = { eol = "¬", nbsp = "¬" , tab = "▸ ", trail = "·" , precedes = "«", extends = "»" }
opt.display:append("uhex") -- Show invalid unicode characters as hex
opt.relativenumber = true -- Relative line-numbers in the gutter
opt.number = true -- Show line number on the current line
opt.cursorline = true -- Highlight the current line
opt.signcolumn = "number"
opt.splitbelow = true -- Split pane below by default
opt.splitright = true -- Split pane to the right by default
opt.scrolloff = 5 -- Always allow 5 empty "lines" beyond start and end of file

-- TODO: Autocmd InsertEnter timeoutlen=0, and then reset on leave

-- Search
opt.showmatch = true
opt.ignorecase = true -- Ignore case for search
opt.smartcase = true -- Ignore case by default, but swap to case-sensitive
                     -- search as soon as at least one uppercase letter is used

-- Font and Color
opt.termguicolors = true -- Enable 24-bit RGB in the terminal UI
cmd "colorscheme base16-tomorrow-night"

-- Keybindings
g.mapleader = " "

key("i", "jj", "<Esc>", { noremap = true, silent = true }) -- Quick exit of insert-mode
key("i", "<Left>", "<NOP>", { noremap = true, silent = true }) -- Do not allow arrows while editing
key("i", "<Down>", "<NOP>", { noremap = true, silent = true })
key("i", "<Up>", "<NOP>", { noremap = true, silent = true })
key("i", "<Right>", "<NOP>", { noremap = true, silent = true })
key("n", "j", "gj", { silent = true }) -- Visual navigation using hjkl even over multiple lines
key("n", "k", "gk", { silent = true })
key("v", "j", "gj", { silent = true })
key("v", "k", "gk", { silent = true })
key("", "<C-h>", "<C-w>h", { noremap = true, silent = true }) -- Easier window pane navigation using Ctrl + hjkl
key("", "<C-j>", "<C-w>j", { noremap = true, silent = true })
key("", "<C-k>", "<C-w>k", { noremap = true, silent = true })
key("", "<C-l>", "<C-w>l", { noremap = true, silent = true })
key("n", "<F3>", "<cmd>noh<CR>", { noremap = true, silent = true }) -- Toggle search highlight
key("", "<Leader>j", "<cmd>bnext<CR>", {}) -- Navigate between buffers using Leader j/k
key("", "<Leader>k", "<cmd>bprevious<CR>", {})
key("", "<Leader>w", "<cmd>bp|bd #<CR>", {}) -- Close the current buffer with leader w
key("", "<C-p>", "<cmd>lua require('telescope.builtin').find_files()<CR>", { noremap = true, silent = true }) -- Fuzzy find file in project
key("", "<Leader>f", "<cmd>lua require('telescope.builtin').live_grep()<CR>", { noremap = true, silent = true }) -- Fuzzy find file in project

-- TODO: Keymaps
--key("", "<Leader><Tab>", "<cmd>NERDTreeToggle<CR>", {})
--key("", "<Leader>r", "<cmd>NERDTreeFind<CR>", {})

-- NeoVIM LSP
key("n", "<leader>d", "<cmd>lua vim.lsp.buf.definition()<CR>", { silent = true })
key("n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>", { silent = true })
key("n", "<leader>k", "<cmd>lua vim.lsp.buf.signature_help()<CR>", { silent = true })
key("n", "<leader>D", "<cmd>lua vim.lsp.buf.type_definition()<CR>", { silent = true })

-- PLUGINS

function telescope()
	local telescope = require("telescope")
	local actions = require("telescope.actions")

	telescope.setup({
		mappings = {
			i = {
				["<C-c>"] = actions.close,
			},
			n = {
				["<C-c>"] = actions.close,
			},
		}
	})

	telescope.load_extension("fzy_native")
end

function lualine()
	local lualine = require("lualine")

	lualine.setup({
		options = {
			-- TODO: Theme
			theme = "auto",
		},
	})
end

function colorizer()
	local colorizer = require("colorizer")

	colorizer.setup()
end

function lspconfig()
	local lsp = require("lspconfig")

	lsp.psalm.setup({
		cmd = {"x", "psalm", "--language-server"}
	})

	-- TODO: FlowJS LSP
	-- TODO: GraphQL LSP
	-- TODO: Java LSP
	-- TODO: Rust
end

function treesitter_after_install()
	cmd ":TSUpdate"
	cmd ":TSInstall bash"
	cmd ":TSInstall c"
	cmd ":TSInstall dockerfile"
	cmd ":TSInstall dot"
	cmd ":TSInstall graphql"
	cmd ":TSInstall haskell"
	cmd ":TSInstall html"
	cmd ":TSInstall java"
	cmd ":TSInstall javascript"
	cmd ":TSInstall json"
	cmd ":TSInstall latex"
	cmd ":TSInstall lua"
	cmd ":TSInstall php"
	cmd ":TSInstall python"
	cmd ":TSInstall ruby"
	cmd ":TSInstall rust"
	cmd ":TSInstall toml"
	cmd ":TSInstall vim"
	cmd ":TSInstall yaml"
end

function treesitter()
	local treesitter_configs = require("nvim-treesitter.configs")

	treesitter_configs.setup({
		highlight = {
			enable = true,
		},
		rainbow = {
			enable = true,
			extended_mode = true, -- Also highlight non-bracket delimiters like html tags, boolean or table: lang -> boolean
		},
	})
end