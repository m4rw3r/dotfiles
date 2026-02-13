# Neovim

Opinionated Neovim config written in Lua with:

- `paq-nvim` + local lazy-loader wrapper (`lua/paq-plus.lua`)
- `snacks.nvim` for picker/grep/notifications/zen
- custom `nvim-tree` vinegar-style behavior (`lua/nvim-tree-vinegar/*`)
- built-in LSP + Tree-sitter setup with per-language indent/trim rules

## Requirements

Core:

- Neovim `0.11+` (this config is tuned for `0.12-dev` APIs)
- `git`
- Tree-sitter parser build toolchain (`cc`, `make`, etc)

Optional (only if you use related features):

- Kitty + remote control (`listen_on`) for cross-pane navigation
- language server binaries listed below

## Install and first run

1. Put this directory at `~/.config/nvim`.
2. Start Neovim once to bootstrap `paq-nvim` and install configured plugins.
3. Update/install Tree-sitter parsers:

```vim
:UserTSUpdate
```

4. Restart Neovim.

## LSP servers

This config enables these servers when available:

- `lua_ls`
- `eslint`
- `ts_ls`
- `rust_analyzer`
- `psalm`

Install notes:

### ESLint

```bash
npm install --global vscode-langservers-extracted@4.8.0
```

### Lua

1. Download a matching archive from
   `https://github.com/LuaLS/lua-language-server/releases`
2. Unpack to `~/.local/share/lua-language-server`
3. Symlink binary into your `PATH`

```bash
mkdir -p ~/.local/share/lua-language-server
tar xvzf lua-language-server-*.tar.gz -C ~/.local/share/lua-language-server
ln -s ~/.local/share/lua-language-server/bin/lua-language-server ~/.local/bin/lua-language-server
```

### TypeScript

Install per project (local dev dependency), not globally:

```bash
npm install --save-dev typescript typescript-language-server
```

Do not install TypeScript LSP globally. Ensure Neovim resolves
`typescript-language-server` from the project-local `node_modules/.bin`.

### Rust

Install with `rustup`:

```bash
rustup component add rust-analyzer
```

You can also install `rust-analyzer` via your system package manager.

### Psalm

This config runs Psalm as:

```bash
x psalm --language-server
```

Make sure `x` and `psalm` are available in your `PATH`, or change
`lua/config/nvim-lspconfig.lua`.

## Useful commands

- `:UserTSUpdate` - update/install configured Tree-sitter parsers
- `:LspStart [name...]` - start LSP(s)
- `:LspStop [name...]` - stop active LSP(s)
- `:LspRestart [name...]` - restart active LSP(s)
- `:LspLog` - open LSP client log in a new tab
- `:StripTrailingWhitespace` - trim trailing whitespace in current buffer
- `:Dark` / `:Light` - switch base16 scheme

## Keymap quick reference

### Global

| Keys | Action |
| --- | --- |
| `<C-p>`, `<M-p>` | Smart file picker |
| `<leader>f` | Grep picker |
| `<leader>j`, `<leader>k` | Next / previous buffer |
| `<leader>w` | Close current buffer |
| `[d`, `]d` | Previous / next diagnostic |
| `<leader>e`, `<leader>E` | Toggle current-line virtual diagnostics / show diagnostic float |
| `<leader><Tab>` | Toggle `nvim-tree` in current pane |
| `<leader>r` | Toggle `nvim-tree` and focus current file |
| `<C-h>`, `<C-j>`, `<C-k>`, `<C-l>` | Vim/Kitty pane navigation |

### LSP and navigation

| Keys | Action |
| --- | --- |
| `K` | Hover docs |
| `<leader>d` | Definition |
| `<leader>D` | Type definition |
| `gd` | Definitions picker |
| `gD` | Declarations picker |
| `gr` | References picker |
| `gI` | Implementations picker |

### Editing defaults

| Keys | Action |
| --- | --- |
| `jj` (insert mode) | Leave insert mode |
| `<Left>`, `<Down>`, `<Up>`, `<Right>` (insert mode) | Disabled |
| `j`, `k` (normal/visual modes) | Move by visual line |

## Language behavior

- default indent width is `4`
- per-language indent/trim config lives in `lua/config/languages.lua`
- trailing whitespace is trimmed on save for configured filetypes
- custom filetype mappings:
  - `*.mdc` -> `markdown`
  - `opencode.json` -> `jsonc`
  - `tsconfig.json` -> `jsonc`

## Kitty integration

If Neovim runs inside Kitty, `<C-h/j/k/l>` will try Kitty pane movement when
there is no Vim window in that direction.

Required scripts:

- `~/.config/kitty/neighboring_window_vim.py`
- `~/.config/kitty/neighboring_window.py`

Also set Kitty remote control (`listen_on` or `--listen-on`) so
`KITTY_LISTEN_ON` is available.

## Config layout

- `init.lua` - entrypoint (options, plugins, keymaps)
- `lua/config/` - plugin and language config modules
- `lua/` - local helpers (`paq-plus`, `languages`, `kitty`, `nvim-tree-vinegar`)
- `ftplugin/` and `after/queries/` - filetype and Tree-sitter overrides

## Troubleshooting

- LSP not attaching:
  - confirm server binary is in `PATH`
  - run `:LspStart` or `:LspStart <server>`
  - inspect `:LspLog`
- Tree-sitter parser missing:
  - install build tools
  - run `:UserTSUpdate`
- Kitty pane navigation errors:
  - configure Kitty `listen_on`
  - ensure required kittens exist in `~/.config/kitty/`
