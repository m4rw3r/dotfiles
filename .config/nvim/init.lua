local key = vim.api.nvim_set_keymap

-- Configuration
local indent = 4
local XDG_DATA_HOME = vim.env.XDG_DATA_HOME or vim.env.HOME .. "/.local/share"
local backupdir = XDG_DATA_HOME .. "/nvim/backup//"
local swapdir = XDG_DATA_HOME .. "/nvim/swap//"
local undodir = XDG_DATA_HOME .. "/nvim/swap/"
local viewdir = XDG_DATA_HOME .. "/nvim/view//"

-- Create required folders
for _, d in pairs({ backupdir, swapdir, undodir, viewdir }) do
	vim.fn.system("mkdir -p '" .. d .. "'")
end

-- Skip built-in plugins
vim.g.loaded_gzip = false
vim.g.loaded_netrwPlugin = false
vim.g.loaded_tarPlugin = false
vim.g.loaded_zip = false
vim.g.loaded_2html_plugin = false
vim.g.loaded_remote_plugins = false

-- Bootstrap packer.nvim
local install_path = vim.fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"

if vim.fn.isdirectory(install_path) == 0 then
  vim.fn.system({"git", "clone", "https://github.com/wbthomason/packer.nvim", install_path})
  vim.cmd("packadd packer.nvim")
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
		"kyazdani42/nvim-tree.lua",
		requires = {
			"kyazdani42/nvim-web-devicons",
		},
		tag = "nightly",
		config = function()
			local tree = require("nvim-tree")

			tree.setup({
				prefer_startup_root = true,
				actions = {
					change_dir = {
						enable = false,
						global = false,
					},
				},
				git = {
					ignore = true,
				},
				view = {
					mappings = {
						custom_only = true,
						list = {
							-- Edit in place since we use vinegar-like
							{ key = "<CR>", action = "edit_in_place" },
							{ key = "o", action = "edit_in_place" },
							-- Recreate the close-window mappings
							{ key = "<C-w>", action = "close" },
							{ key = "<Leader>w", action = "close" },
							-- Visibility
							{ key = "I", action = "toggle_git_ignored" },
							{ key = "H", action = "toggle_dotfiles" },
							-- NERDTree like bindings
							{ key = "s", action = "split" },
							{ key = "i", action = "vsplit" },
							{ key = "P", action = "parent" },
							{ key = "K", action = "first_sibling" },
							{ key = "J", action = "last_sibling" },
							{ key = "U", action = "dir_up" },
							{ key = "<", action = "prev_sibling" },
							{ key = ">", action = "next_sibling" },
							{ key = "R", action = "refresh" },
							{ key = "x", action = "close_node" },
							{ key = "?", action = "toggle_help" },
							-- File management bindings
							{ key = "a", action = "create" },
							{ key = "d", action = "remove" },
							{ key = "r", action = "rename" },
						},
					},
				},
			})
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
local function stripTrailingWhitespace()
	local c = vim.api.nvim_win_get_cursor(0)

	vim.cmd("%s/\\s\\+$//e")

	vim.api.nvim_win_set_cursor(0, c)
end
vim.api.nvim_create_user_command("StripTrailingWhitespace", stripTrailingWhitespace, {})

local indentgroup = vim.api.nvim_create_augroup("indent", {})

for filetype, config in pairs(indents) do
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
vim.opt.showmatch = true
vim.opt.ignorecase = true -- Ignore case for search
vim.opt.smartcase = true -- Ignore case by default, but swap to case-sensitive
                     -- search as soon as at least one uppercase letter is used

-- Font and Color
vim.opt.termguicolors = true -- Enable 24-bit RGB in the terminal UI

-- Keybindings
vim.g.mapleader = " "
vim.opt.omnifunc = "v:lua.vim.lsp.omnifunc"

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
vim.keymap.set("", "<C-p>", function() require('telescope.builtin').find_files() end) -- Fuzzy find file in project
vim.keymap.set("", "<M-p>", function() require('telescope.builtin').find_files({no_ignore = true}) end) -- Fuzzy find file in project, ignoring ignores
vim.keymap.set("", "<Leader>f", function() require('telescope.builtin').live_grep() end) -- Fuzzy search file in project
-- NeoVIM LSP
vim.keymap.set("n", "<leader>d", vim.lsp.buf.definition)
vim.keymap.set("n", "K", vim.lsp.buf.hover)
vim.keymap.set("n", "<leader>k", vim.lsp.buf.signature_help)
vim.keymap.set("n", "<leader>D", vim.lsp.buf.type_definition)
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float)
-- nvim-tree
-- Toggle nvim-tree replacing current window
vim.keymap.set("", "<Leader><Tab>", function()
	local treeView = require("nvim-tree.view")

	if treeView.is_visible() then
		treeView.close()
	else
		-- We have to manually reimplement parts of
		-- open_replacing_current_buffer in this case to be able to show
		-- nvim-tree with a new buffer
		local tree = require("nvim-tree")
		local treeCore = require("nvim-tree.core")
		local treeRenderer = require("nvim-tree.renderer")
		local cwd = vim.fn.getcwd();
		local buf = api.nvim_get_current_buf()
		local bufname = api.nvim_buf_get_name(buf)

		if not treeCore.get_explorer() or cwd ~= treeCore.get_cwd() then
			treeCore.init(cwd)
		end

		treeView.open_in_current_win({ hijack_current_buf = false, resize = false })
		treeRenderer.draw()

		-- Only search for the current file if we have a saved file open
		if bufname ~= "" and vim.loop.fs_stat(bufname) ~= nil then
			require("nvim-tree.actions.find-file").fn(bufname)
		end
	end
end)
-- Find file in nvim-tree replacing current window
vim.keymap.set("", "<Leader>r", function()
	local treeView = require("nvim-tree.view")

	if treeView.is_visible() then
		treeView.close()
	else
		local tree = require("nvim-tree")
		local previous_buf = api.nvim_get_current_buf()

		tree.open_replacing_current_buffer(vim.fn.getcwd())
		tree.find_file(false, previous_buf)
	end
end)