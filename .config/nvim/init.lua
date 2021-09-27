local api = vim.api
local cmd = vim.cmd
local env = vim.env
local fn = vim.fn
local g = vim.g
local key = api.nvim_set_keymap
local opt = vim.opt

-- Configuration
local indent = 4
local XDG_DATA_HOME = env.XDG_DATA_HOME or env.HOME .. "/.local/share"
local backupdir = XDG_DATA_HOME .. "/nvim/backup//"
local swapdir = XDG_DATA_HOME .. "/nvim/swap//"
local undodir = XDG_DATA_HOME .. "/nvim/swap/"
local viewdir = XDG_DATA_HOME .. "/nvim/view//"

-- Create required folders
for _, d in pairs({ backupdir, swapdir, undodir, viewdir }) do
	fn.system("mkdir -p '" .. d .. "'")
end

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
	use { "lewis6991/gitsigns.nvim", requires = { "nvim-lua/plenary.nvim" }}

	-- UI
	--
	-- Status-line replacement
	use {
		"shadmansaleh/lualine.nvim",
		requires = {"kyazdani42/nvim-web-devicons" },
		config = lualine,
	}
	-- Allow window navigation outside of NeoVIM when in tmux
	use { "christoomey/vim-tmux-navigator" }
	-- Rainbow parenthesis using treesitter
	use { "p00f/nvim-ts-rainbow" }
	-- Show colors
	use { "norcalli/nvim-colorizer.lua", config = colorizer }
	use { "preservim/nerdtree", config = nerdtree }

	-- Language integration
	--
	-- LSP
	use { "neovim/nvim-lspconfig", config = lspconfig }
	use { "nvim-lua/completion-nvim" }
	use { "nvim-treesitter/nvim-treesitter", run = treesitter_after_install, config = treesitter }

	-- Colorschemes
	use { "RRethy/nvim-base16", config = base16_config }
end)

-- Files
opt.fileencoding = "utf-8"
opt.fileencodings = "ucs-bom,utf-8"
opt.binary = true -- Allow binary file ediding without mangling to UTF-8
opt.eol = false -- Do not append linebreak at EOF
opt.backup = true -- Backup files
opt.undofile = true -- Save undo in files
-- We have to replace the list to avoid having backups in the current folder
opt.backupdir = { backupdir }
opt.directory = { swapdir }
opt.undodir = undodir
opt.viewdir = viewdir

-- Tabs and indent
opt.tabstop = indent
opt.shiftwidth = indent
opt.foldenable = false

local indents = {
	cabal = { expandtab = true },
	haskell = { expandtab = true },
	html = { autoindent = false },
	javascript = { expandtab = true, indent = 2, trim = true, autoindent = false },
	json = { expandtab = true, indent = 2, trim = true },
	php = { expandtab = true, trim = true },
	python = { expandtab = true },
	ruby = { indent = 2 },
	rust = { expandtab = true, trim = true },
	sql = { autoindent = false },
	xml = { expandtab = true, indent = 2, trim = true },
	yaml = { indent = 2 },
}

-- Global function for stripping whitespace from files
function _G.StripTrailingWhitespace()
	local c = api.nvim_win_get_cursor(0)

	cmd("%s/\\s\\+$//e")

	api.nvim_win_set_cursor(0, c)
end

-- Use an autogroup to avoid multiple groups being registered
function autogroup(name, commands)
	cmd("augroup " .. name)
	cmd("autocmd!")

	for _, line in ipairs(commands) do
		local command = table.concat(vim.tbl_flatten{ "autocmd", line }, " ")

		cmd(command)
	end

	cmd("augroup END")
end

function addIndentCommands(autogroup, filetype, config)
	setmetatable(config, { __index = {
		indent = nil,
		expandtab = false,
		trim = false,
		autoindent = true,
	} } )

	if config.indent then
		table.insert(autogroup, {"FileType", filetype, "setlocal", "shiftwidth=" .. config.indent, "tabstop=" .. config.indent})
	end

	if config.expandtab then
		table.insert(autogroup, {"FileType", filetype, "setlocal", "expandtab"})
	end

	if config.trim then
		table.insert(autogroup, {"FileType", filetype, "autocmd", "BufWritePre", "<buffer>", "lua StripTrailingWhitespace()"})
	end

	if not config.autoindent then
		table.insert(autogroup, {"FileType", filetype, "setlocal", "indentexpr="})
	end
end

local indentgroup = {}

for k, v in pairs(indents) do
	addIndentCommands(indentgroup, k, v)
end

autogroup("indent", indentgroup)

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
opt.signcolumn = "number" -- Show signs in the number column
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

-- Keybindings
g.mapleader = " "
opt.omnifunc = "v:lua.vim.lsp.omnifunc"

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
-- NeoVIM LSP
key("n", "<leader>d", "<cmd>lua vim.lsp.buf.definition()<CR>", { noremap = true, silent = true })
key("n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>", { noremap = true, silent = true })
key("n", "<leader>k", "<cmd>lua vim.lsp.buf.signature_help()<CR>", { noremap = true, silent = true })
key("n", "<leader>D", "<cmd>lua vim.lsp.buf.type_definition()<CR>", { noremap = true, silent = true })

-- TODO: Keymaps
--key("", "<Leader><Tab>", "<cmd>NERDTreeToggle<CR>", {})
--key("", "<Leader>r", "<cmd>NERDTreeFind<CR>", {})

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
			theme = "auto",
		},
	})
end

function colorizer()
	local colorizer = require("colorizer")

	colorizer.setup()
end

function nerdtree()
	vim.g.NERDTreeShowHidden = 1
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

function base16_config()
	vim.cmd "colorscheme base16-tomorrow-night"
	-- Shortcuts to swap the theme
	-- TODO: When https://github.com/neovim/neovim/pull/11613 is merged, use the Lua API
	vim.cmd "command! Dark colorscheme base16-tomorrow-night"
	vim.cmd "command! Light colorscheme base16-tomorrow"
end