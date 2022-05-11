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
		config = function()
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
				},
			})

			telescope.load_extension("fzy_native")
		end
	}
	use { "lewis6991/gitsigns.nvim", requires = { "nvim-lua/plenary.nvim" }}

	-- UI
	--
	-- Status-line replacement
	use {
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
	}
	-- Allow window navigation outside of NeoVIM when in tmux
	use { "christoomey/vim-tmux-navigator" }
	-- Rainbow parenthesis using treesitter
	use { "p00f/nvim-ts-rainbow" }
	-- Show colors
	use {
		"norcalli/nvim-colorizer.lua",
		config = function()
			local colorizer = require("colorizer")

			colorizer.setup()
		end
	}
	use {
		"preservim/nerdtree",
		config = function()
			vim.g.NERDTreeShowHidden = 1
		end
	}

	-- Language integration
	--
	-- LSP
	use {
		"neovim/nvim-lspconfig",
		config = function()
			local lsp = require("lspconfig")

			lsp.psalm.setup({
				cmd = {"x", "psalm", "--language-server"},
				flags = { debounce_text_changes = 150 },
			})

			-- TODO: FlowJS LSP
			-- TODO: GraphQL LSP
			-- TODO: Java LSP
			-- TODO: Rust
		end
	}
	use { "nvim-lua/completion-nvim" }
	use {
		"nvim-treesitter/nvim-treesitter",
		run = function()
			-- Update instead of install, since then it will install it if it is missing
			vim.cmd("TSUpdate bash")
			vim.cmd("TSUpdate c")
			vim.cmd("TSUpdate dockerfile")
			vim.cmd("TSUpdate dot")
			vim.cmd("TSUpdate graphql")
			vim.cmd("TSUpdate haskell")
			vim.cmd("TSUpdate html")
			vim.cmd("TSUpdate java")
			vim.cmd("TSUpdate javascript")
			vim.cmd("TSUpdate json")
			vim.cmd("TSUpdate latex")
			vim.cmd("TSUpdate lua")
			vim.cmd("TSUpdate php")
			vim.cmd("TSUpdate python")
			vim.cmd("TSUpdate ruby")
			vim.cmd("TSUpdate rust")
			vim.cmd("TSUpdate toml")
			vim.cmd("TSUpdate vim")
			vim.cmd("TSUpdate yaml")
		end,
		config = function()
			local treesitter_configs = require("nvim-treesitter.configs")

			treesitter_configs.setup({
				highlight = {
					enable = true,
				},
				indent = {
					disable = { "php" },
					enable = true,
				},
				rainbow = {
					enable = true,
					extended_mode = true, -- Also highlight non-bracket delimiters like html tags, boolean or table: lang -> boolean
				},
			})
		end
	}
	use {
		"folke/trouble.nvim",
		requires = "kyazdani42/nvim-web-devicons",
		config = function()
			require("trouble").setup {}
		end
	}

	-- Colorschemes
	use {
		"RRethy/nvim-base16",
		config = function()
			vim.cmd "colorscheme base16-tomorrow-night"
			-- Shortcuts to swap the theme
			-- TODO: When https://github.com/neovim/neovim/pull/11613 is merged
			-- and released, use the Lua API
			vim.cmd "command! Dark colorscheme base16-tomorrow-night"
			vim.cmd "command! Light colorscheme base16-tomorrow"
		end
	}
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
	php = { expandtab = true, trim = true, autoindent = false },
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
local function autogroup(name, commands)
	vim.cmd("augroup " .. name)
	vim.cmd("autocmd!")

	for _, line in ipairs(commands) do
		local command = table.concat(vim.tbl_flatten{ "autocmd", line }, " ")

		vim.cmd(command)
	end

	vim.cmd("augroup END")
end

local function addIndentCommands(autogroup, filetype, config)
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

vim.diagnostic.config({
	virtual_text = true,
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
-- Telescope
key("", "<C-p>", "<cmd>lua require('telescope.builtin').find_files()<CR>", { noremap = true, silent = true }) -- Fuzzy find file in project
key("", "<M-p>", "<cmd>lua require('telescope.builtin').find_files({no_ignore = true})<CR>", { noremap = true, silent = true }) -- Fuzzy find file in project, ignoring ignores
key("", "<Leader>f", "<cmd>lua require('telescope.builtin').live_grep()<CR>", { noremap = true, silent = true }) -- Fuzzy find file in project
-- NeoVIM LSP
key("n", "<leader>d", "<cmd>lua vim.lsp.buf.definition()<CR>", { noremap = true, silent = true })
key("n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>", { noremap = true, silent = true })
key("n", "<leader>k", "<cmd>lua vim.lsp.buf.signature_help()<CR>", { noremap = true, silent = true })
key("n", "<leader>D", "<cmd>lua vim.lsp.buf.type_definition()<CR>", { noremap = true, silent = true })
key("n", "<leader>e", "<cmd>lua vim.diagnostic.open_float()<CR>", { noremap = true, silent = true })
-- NERDTree
key("", "<Leader><Tab>", "<cmd>NERDTreeToggle<CR>", {})
key("", "<Leader>r", "<cmd>NERDTreeFind<CR>", {})