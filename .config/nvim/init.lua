-- Configuration
local indent = 4
local XDG_DATA_HOME = vim.env.XDG_DATA_HOME or vim.env.HOME .. "/.local/share"
local backupdir = XDG_DATA_HOME .. "/nvim/backup//"
local swapdir = XDG_DATA_HOME .. "/nvim/swap//"
local undodir = XDG_DATA_HOME .. "/nvim/swap/"
local viewdir = XDG_DATA_HOME .. "/nvim/view//"

-- Skip built-in plugins
vim.g.loaded_gzip = false
vim.g.loaded_netrwPlugin = false
vim.g.loaded_tarPlugin = false
vim.g.loaded_zip = false
vim.g.loaded_2html_plugin = false
vim.g.loaded_remote_plugins = false

local ok, impatient = pcall(require, "impatient")
if ok then
	impatient.enable_profile()
end

-- TODO: Maybe replace packer?
local ok, packer = pcall(require, "packer")
if not ok then 
	-- Create required folders
	for _, d in pairs({ backupdir, swapdir, undodir, viewdir }) do
		vim.fn.system("mkdir -p '" .. d .. "'")
	end

	-- Bootstrap packer.nvim
	local install_path = vim.fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"

	if vim.fn.isdirectory(install_path) == 0 then
	  vim.fn.system({"git", "clone", "https://github.com/wbthomason/packer.nvim", install_path})
	  vim.cmd("packadd packer.nvim")
	end

	packer = require("packer")
end

packer.startup(function(use)
	use { "wbthomason/packer.nvim" }

	use { "lewis6991/impatient.nvim" }
	use { "tweekmonster/startuptime.vim" }

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
			-- This is a major addition to better support smooth vinegar-like
			-- window-replacement with opening files in splits, then restoring
			-- the previous window contents.
			local tree = require("nvim-tree")
			local treeView = require("nvim-tree.view")
			local treeLib = require("nvim-tree.lib")
			local treeCore = require("nvim-tree.core")
			local treeRenderer = require("nvim-tree.renderer")
			local treeEvents = require("nvim-tree.events")
			local treeUtils = require("nvim-tree.utils")

			-- Track the previous window settings when replacing, so we can
			-- close the tree view and swap back when opening new splits
			local prevWindow = nil

			-- Reimplementation of open file which works when we are replacing
			-- the current buffer
			-- TODO: More split options?
			local function openFile(openCommand)
				return function(node)
					if not node or node.name == ".." then
						return
					end

					local filename = node.absolute_path

					if node.link_to and not node.nodes then
						filename = node.link_to
					elseif node.nodes ~= nil then
						return treeLib.expand_or_collapse(node)
					end

					vim.cmd(openCommand .. "" .. vim.fn.fnameescape(filename))
				end
			end

			-- Custom changedir which properly handles rerendering in the
			-- current window, as well as changing to the directory of a file
			local function changeDir(node)
				if not node then
					return
				end

				local filename = nil

				if node.name == ".." then
					-- TODO: Replace treeUtils with core-functions?
					filename = vim.fn.fnamemodify(treeUtils.path_remove_trailing(treeCore.get_cwd()), ":h")
				elseif node.link_to then
					filename = node.link_to
				else
					filename = node.absolute_path
				end

				while vim.fn.isdirectory(filename) == 0 do
					filename = vim.fn.fnamemodify(treeUtils.path_remove_trailing(filename), ":h")
				end

				-- TODO: Configurable?
				-- TODO: Maybe use local cd (:lcd) instead?
				vim.cmd("cd " .. vim.fn.fnameescape(filename))

				treeCore.init(filename)
				treeRenderer.draw()
			end

			-- We have to manually reimplement parts of
			-- open_replacing_current_buffer in this case to be able to show
			-- nvim-tree with a new buffer
			local function openReplacingBuffer()
				local cwd = vim.fn.getcwd();

				-- Save previous window and options so we can restore when closing
				prevWindow = {
					buffer = vim.api.nvim_get_current_buf(),
					opts = {}
				}

				for k, _ in pairs(treeView.View.winopts) do
					prevWindow.opts[k] = vim.opt_local[k]
				end

				-- Reinit if the file we are opening from is not in the current directory
				if not treeCore.get_explorer() or cwd ~= treeCore.get_cwd() then
					treeCore.init(cwd)
				end

				treeView.open_in_current_win({ hijack_current_buf = false, resize = false })
				treeRenderer.draw()
			end

			-- Reimplementation of nvim-tree.view.close restoring the original
			-- buffer and window options
			local function closeTree()
				local treeWinnr = treeView.get_winnr()

				treeView.abandon_current_window()

				if not prevWindow then
					vim.cmd("new")

					return
				end

				-- Move to window just in case
				if treeWinnr then
					vim.api.nvim_set_current_win(treeWinnr)
				end

				-- Restore window contents
				vim.cmd("buffer " .. prevWindow.buffer)

				-- Restore window settings
				for k, _ in pairs(treeView.View.winopts) do
					vim.opt_local[k] = prevWindow.opts[k]
				end

				prevWindow = nil

				treeEvents._dispatch_on_tree_close()
			end

			local function toggleTree(onOpen)
				local currentBuffer = vim.api.nvim_get_current_buf()

				if treeView.is_visible() then
					-- If the tree view is visible but this is not the buffer, move focus to the buffer
					local treeBuffer = treeView.get_bufnr()

					if currentBuffer == treeBuffer then
						closeTree()

						return
					else
						treeView.focus()
					end
				else
					openReplacingBuffer()
				end

				if onOpen then
					onOpen(currentBuffer)
				end
			end

			tree.setup({
				prefer_startup_root = true,
				git = {
					ignore = true,
				},
				view = {
					mappings = {
						custom_only = true,
						list = {
							-- Edit in place since we use vinegar-like
							{
								key = {"<CR>", "o"},
								action = "edit_in_place",
								desc = "Open a file or directory, replacing the explorer buffer",
							},
							-- Recreate the close-window mappings
							{
								key = {"<C-w>", "<Leader>w"},
								-- We have to have both an action and an
								-- action_cb, the action_cb will replace any
								-- default action
								action = "close",
								action_cb = closeTree,
								desc = "Close and return to the previous buffer",
							},
							-- Visibility
							{ key = "I", action = "toggle_git_ignored", desc = "Toggle showing gitignored files" },
							{ key = "H", action = "toggle_dotfiles", desc = "Toggle showing hidden files" },
							-- NERDTree like bindings
							{ key = "s", action = "split", action_cb = openFile("split"), desc = "Open the given file in a horizontal split" },
							{ key = "i", action = "vsplit", action_cb = openFile("vsplit"), desc = "Open the given file in a vertical split" },
							{ key = "p", action = "parent", desc = "Go to the parent directory" },
							{ key = "K", action = "first_sibling", desc = "Go to the first sibling" },
							{ key = "J", action = "last_sibling", desc = "Go to the last sibling" },
							{ key = "U", action = "dir_up", desc = "Navigate to the parent of the current file/directory" },
							{ key = "<", action = "prev_sibling", desc = "Go to previous siblilng" },
							{ key = ">", action = "next_sibling", desc = "Go to next sibling" },
							{ key = "R", action = "refresh", desc = "Refresh the directory tree" },
							{ key = "x", action = "close_node", desc = "Close the current directory or parent" },
							{ key = "?", action = "toggle_help", desc = "Toggle help" },
							{
								key = "C",
								action = "change_dir",
								action_cb = changeDir,
								desc = "Changes the current directory to the selected directory, or the directory of the selected file",
							},
							-- File management bindings
							{ key = "a", action = "create", desc = "Create file/directory, directories end in '/'" },
							{ key = "d", action = "remove", desc = "Delete file/directory" },
							{ key = "r", action = "rename", desc = "Rename file/directory" },
						},
					},
				},
			})

			local function findCurrentBuffer(currentBuffer)
				local bufname = vim.api.nvim_buf_get_name(currentBuffer)
				-- Only search for the current file if we have a saved file open
				if bufname ~= "" and vim.loop.fs_stat(bufname) ~= nil then
					require("nvim-tree.actions.find-file").fn(bufname)
				end
			end

			-- Toggle nvim-tree replacing current window
			vim.keymap.set("", "<Leader><Tab>", function() toggleTree() end)
			-- Find file in nvim-tree replacing current window
			vim.keymap.set("", "<Leader>r", function() toggleTree(findCurrentBuffer) end)
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
			vim.cmd("colorscheme base16-tomorrow-night")
			-- Shortcuts to swap the theme
			vim.api.nvim_create_user_command("Dark", "colorscheme base16-tomorrow-night", {})
			vim.api.nvim_create_user_command("Light", "colorscheme base16-tomorrow", {})
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

vim.keymap.set("i", "jj", "<Esc>", { silent = true }) -- Quick exit of insert-mode
vim.keymap.set("i", "<Left>", "<NOP>", { silent = true }) -- Do not allow arrows while editing
vim.keymap.set("i", "<Down>", "<NOP>", { silent = true })
vim.keymap.set("i", "<Up>", "<NOP>", { silent = true })
vim.keymap.set("i", "<Right>", "<NOP>", { silent = true })
vim.keymap.set("n", "j", "gj", { noremap = false, silent = true }) -- Visual navigation using hjkl even over multiple lines
vim.keymap.set("n", "k", "gk", { noremap = false, silent = true })
vim.keymap.set("v", "j", "gj", { noremap = false, silent = true })
vim.keymap.set("v", "k", "gk", { noremap = false, silent = true })
vim.keymap.set("", "<C-h>", "<C-w>h", { silent = true }) -- Easier window pane navigation using Ctrl + hjkl
vim.keymap.set("", "<C-j>", "<C-w>j", { silent = true })
vim.keymap.set("", "<C-k>", "<C-w>k", { silent = true })
vim.keymap.set("", "<C-l>", "<C-w>l", { silent = true })
vim.keymap.set("n", "<F3>", "<cmd>noh<CR>", { silent = true }) -- Toggle search highlight
vim.keymap.set("", "<Leader>j", "<cmd>bnext<CR>", { noremap = false }) -- Navigate between buffers using Leader j/k
vim.keymap.set("", "<Leader>k", "<cmd>bprevious<CR>", { noremap = false })
vim.keymap.set("", "<Leader>w", "<cmd>bp|bd #<CR>", { noremap = false }) -- Close the current buffer with leader w
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