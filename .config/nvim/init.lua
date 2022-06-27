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

local ok, paq = pcall(require, "paq")
if not ok then
  -- Create required folders
  for _, d in pairs({ backupdir, swapdir, undodir, viewdir }) do
    vim.fn.system("mkdir -p '" .. d .. "'")
  end

  -- Bootstrap paq-nvim
  local install_path = vim.fn.stdpath("data") .. "/site/pack/paqs/start/paq-nvim"

  if vim.fn.isdirectory(install_path) == 0 then
    vim.fn.system({"git", "clone", "https://github.com/savq/paq-nvim.git", install_path})
    vim.cmd("packadd paq")
  end

  paq = require("paq")
end

local pluginPath = vim.fn.stdpath("data") .. "/site/pack/paqs"

local function isLocal(spec)
  return string.sub(spec[1], 1, 1) == "."
end

local function localPath(spec)
  if isLocal(spec) then
    -- Drop any trailing slashes, also remove the leading .
    return vim.fn.stdpath("config") .. (string.sub(spec[1], -1) == "/" and string.sub(spec[1], 2, -1) or string.sub(spec[1], 2))
  else
    return pluginPath .. (spec.opt and "/opt/" or "/start/") .. spec.name
  end
end

local function isInstalled(spec)
  return vim.fn.isdirectory(localPath(spec)) ~= 0
end

local specs = {}
local packages = {}

local function addPackage(spec)
  if type(spec) == "string" then
    spec = { spec }
  end

  -- TODO: Url?
  name = spec.as or spec[1]:match("/([%w-_.]+)$")

  spec.loaded = not spec.opt
  spec.name = name

  specs[name] = spec

  if isLocal(spec) then
    -- Local module
  else
    table.insert(packages, {
      spec[1],
      as = spec.as,
      opt = spec.opt,
      branch = spec.branch,
      pin = spec.pin,
      run = spec.run,
      url = spec.url,
    })
  end

  -- TODO: Determine required packages for opts

  if spec.requires then
    if type(spec.requires) == "string" then
      addPackage(spec.requires)
    else
      for _, dep in pairs(spec.requires) do
        addPackage(dep)
      end
    end
  end
end

local function lazyLoad(spec)
  if spec.loaded then
    return
  end

  -- print("Loading " .. spec.name)

  spec.loaded = true

  -- TODO: Load dependencies (ie. wants)

  if isInstalled(spec) then
    for _, name in pairs(spec.wants or {}) do
      if specs[name] then
        lazyLoad(specs[name])
      else
        -- TODO: log
      end
    end

    if not isLocal(spec) then
      vim.cmd("packadd " .. spec.name)
    else
      vim.o.runtimepath = vim.o.runtimepath .. "," .. vim.fn.escape(localPath(spec), '\\,')
    end

    if spec.config then
      -- print("Configuring " .. spec.name)
      spec.config()
    end
  else
    -- TODO: log
  end

  -- TODO: Load after?
end

local function registerLazyLoaders(spec)
  -- FIXME: events
  -- FIXME: filetypes
  for _, cmd in pairs(spec.cmd or {}) do
    if type(cmd) == "string" then
      cmd = { cmd }
    end

    local called = false

    vim.api.nvim_create_user_command(
      cmd[1],
      function(cause)
        -- Sanity check to avoid loops
        if called then
          -- TODO: Error
          return print("No plugin registered command " .. cmd[1])
        end

        called = true

        lazyLoad(spec)

        local lines = cause.line1 == cause.line2 and '' or (cause.line1 .. ',' .. cause.line2)

        -- Reconstruct the command
        vim.cmd(string.format('%s %s%s%s %s', cause.mods or '', lines, cmd[1], cause.bang and "!" or "", cause.args))
      end,
      {
        -- silent = true,
        desc = cmd.desc,
        -- We have to allow all of these just in case since we do not know
        bang = true,
        nargs = "*",
        range = true,
        complete = "file",
      }
    )
  end

  for _, key in pairs(spec.keys or {}) do
    local called = false

    if type(key) == "string" then
      key = { "", key }
    end

    vim.keymap.set(
      key[1],
      key[2],
      function()
        -- Sanity check to avoid loops
        if called then
          -- TODO: Error
          return print("No plugin registered keybind " .. key[2])
        end

        called = true

        lazyLoad(spec)

        local extra = ''
        while true do
          local c = vim.fn.getchar(0)
          if c == 0 then
            break
          end
          extra = extra .. vim.fn.nr2char(c)
        end

        local escaped_keys = vim.api.nvim_replace_termcodes(key[2] .. extra, true, true, true)

        vim.api.nvim_feedkeys(escaped_keys, "m", true)
      end,
      {
        -- silent = true,
        docs = key.docs,
      }
    )
  end
end

local function loadPackage(spec)
  if spec.opt then
    registerLazyLoaders(spec)
  elseif spec.config and isInstalled(spec) then
    spec.config()
  end
end

local function initPackages(fn)
  fn(addPackage)
  paq(packages)
end

function loadPackages()
  for _, spec in pairs(specs) do
    loadPackage(spec)
  end
end

initPackages(function(use)
  use { "savq/paq-nvim" }

  -- Lua bytecode cache to speed up launching
  use { "lewis6991/impatient.nvim" }
  use { "tweekmonster/startuptime.vim" }
  -- Faster filetype detection
  use { "nathom/filetype.nvim" }

  -- Utilities
  --
  -- Automatically sets the working-directory to the detected project root if any
  use { "ygm2/rooter.nvim" }
  -- Fuzzy finder for files, and in files
  use {
    "nvim-telescope/telescope.nvim",
    requires = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope-fzy-native.nvim",
    },
    -- Use wants instead of after to make sure we load the required modules
    -- before running telescope:
    wants = {
      "plenary.nvim",
      "telescope-fzy-native.nvim"
    },
    -- Lazy
    opt = true,
    -- Important that this require does not immediately perform further
    -- requires, but that it is deferred to the config function:
    -- TODO: This is annoying, requries a full restart of neovim for this to properly work due to compiling
    keys = require("config.telescope").keys,
    cmd = require("config.telescope").cmd,
    config = function() require("config.telescope").config() end
  }
  use { "lewis6991/gitsigns.nvim" }

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
    "./plugins/nvim-tree-vinegar.nvim",
    requires = {
      {
        "kyazdani42/nvim-tree.lua",
        tag = "nightly",
      },
      "lkyazdani42/nvim-web-devicons",
    },
    wants = {
      "nvim-tree.lua",
      "nvim-web-devicons",
    },
    -- Lazy load on the custom tree-display commands
    opt = true,
    keys = require("config.nvim-tree").keys,
    cmd = require("config.nvim-tree").cmd,
    config = function() require("config.nvim-tree").config() end
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
    run = function() require("config.treesitter").run() end,
    config = function() require("config.treesitter").config() end
  }
  use {
    "folke/trouble.nvim",
    requires = { "kyazdani42/nvim-web-devicons" },
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

require("languages").registerIndentAutogroup()

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

-- NeoVIM LSP
vim.keymap.set("n", "<leader>d", vim.lsp.buf.definition)
vim.keymap.set("n", "K", vim.lsp.buf.hover)
vim.keymap.set("n", "<leader>k", vim.lsp.buf.signature_help)
vim.keymap.set("n", "<leader>D", vim.lsp.buf.type_definition)
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float)

-- TODO: Any way we can schedule this? Maybe just move it into a plugin folder of some kind
loadPackages()
