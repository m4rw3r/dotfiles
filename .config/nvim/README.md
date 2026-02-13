# NeoVIM

## Language Servers

Some language-servers requires system- or user-wide installation.

### ESlint

```bash
npm install --global vscode-langservers-extracted@4.8.0
```

### LUA

Requires lua-language-server

1. Download the suitable archive from https://github.com/LuaLS/lua-language-server/releases
2. Unpack in ~/.local/share/lua-language-server

```bash
mkdir ~/.local/share/lua-language-server && tar xvzf lua-language-server-*.tar.gz -C ~/.local/share/lua-language-server
# Create link
ln -s ~/.local/share/lua-language-server/bin/lua-language-server ~/.local/bin/lua-language-server
```
