local get_active_clients = function(prefix)
  return vim
    .iter(vim.lsp.get_clients())
    :filter(function(client)
      return prefix == nil or client.name:sub(1, #prefix) == prefix
    end)
    :totable()
end

local get_active_client_names = function(prefix)
  local t = vim.tbl_map(function(client)
    return client.name
  end, get_active_clients(prefix))

  table.sort(t)

  return t
end

-- Returns a list of LSP-clients which have their configuration enabled
local get_configured_client_names = function(prefix)
  local c = {};

  for name, _ in pairs(vim.lsp._enabled_configs) do
    if (prefix == nil or name:sub(1, #prefix) == prefix) then
      table.insert(c, name)
    end
  end

  table.sort(c)

  return c
end

-- Stops the given list, or all, clients, returning the stopped client instances
local function stop_clients(names)
  names = next(names) and names or get_active_client_names()

  local clients = {}

  -- Just disabling them does not seem to stop the clients, we have to manually get the clients and call stop
  for _, name in ipairs(names) do
    if vim.lsp.config[name] == nil then
      vim.notify(("Invalid server name '%s'"):format(name))
    else
      for _, client in ipairs(vim.lsp.get_clients({ name = name })) do
        table.insert(clients, client)

        client:stop()
      end
    end
  end

  return clients
end

local M = {
  "neovim/nvim-lspconfig",
  keys = {
    { "n", "<leader>d", vim.lsp.buf.definition },
    { "n", "<leader>D", vim.lsp.buf.type_definition },
    { "n", "K", vim.lsp.buf.hover },
    { "n", "<leader>K", vim.lsp.buf.signature_help },
    -- { "n", "<leader>K", function() vim.lsp.buf.hover({ border = "rounded" }) end },
    -- { "n", "<leader>e", vim.diagnostic.open_float },
  },
  cmds = {
    {
      "LspStart",
      function(info)
        if next(info.fargs) then
          for _, name in ipairs(info.fargs) do
            vim.lsp.enable(name, true)
          end
        else
          -- Just trigger FileType autocmd to make LSP load the appropriate clients
          vim.api.nvim_exec_autocmds("FileType", {})
        end
      end,
      {
        desc = "Starts the given client(s), or starts all applicable clients if none are supplied",
        nargs = "*",
        complete = get_configured_client_names,
      },
    },
    {
      -- Override the default to provide the default operation on all clients
      "LspRestart",
      function(info)
        local names = next(info.fargs) and info.fargs or get_active_client_names()
        local clients = stop_clients(names)

        -- Wait for them to stop
        local timer = assert(vim.uv.new_timer())
        timer:start(500, 0, function()
          for _, client in ipairs(clients) do
            -- Schedule-wrap is required for vim-api in libuv-scope
            vim.schedule_wrap(function(x)
              -- Start the client with the old configuration
              vim.lsp.start(x)
            end)(client.config)
          end
        end)
      end,
      {
        desc = "Restart the given client(s), if none are supplied all active will be restarted",
        nargs = "*",
        complete = get_active_client_names,
      },
    },
    {
      -- Do the same for LspStop
      "LspStop",
      function(info)
        stop_clients(next(info.fargs) and info.fargs or get_active_client_names())
      end,
      {
        desc = "Disable and stop the given client(s), if none are supplied all active clients will be stopped",
        nargs = "*",
        complete = get_active_client_names,
      },
    },
    {
      -- Reintroduce LspLog, it is missing after NeoVim 0.11.2
      "LspLog",
      function()
        vim.cmd(string.format('tabnew %s', vim.lsp.get_log_path()))
      end,
      {
        desc = 'Opens the Nvim LSP client log.',
      },
    },
  },
}

function M.config()
  local function configLsp(name, cfg)
    -- This is new but does not properly configure or enable the LSPs without enabling
    vim.lsp.config(name, cfg)
    vim.lsp.enable(name)

    -- Deprecated, but works as of 0.12-dev
    --
    --local lsp = require("lspconfig")
    --
    --lsp[name].setup(cfg)
  end

  configLsp("psalm", {
    cmd = {"x", "psalm", "--language-server"},
    flags = { debounce_text_changes = 150 },
    root_dir = function()
      return vim.fs.dirname(vim.fs.find({ "composer.json" }, { upward = true })[1])
    end,
  })

  configLsp("rust_analyzer", {})
  configLsp("ts_ls", {})

  -- Requires lua-language-server
  --
  -- Download the suitable archive from https://github.com/LuaLS/lua-language-server/releases
  -- Unpack in ~/.local/share/lua-language-server
  --   mkdir ~/.local/share/lua-language-server && tar xvzf lua-language-server-*.tar.gz -C ~/.local/share/lua-language-server
  -- Create link
  --   ln -s ~/.local/share/lua-language-server/bin/lua-language-server ~/.local/bin/lua-language-server
  configLsp("lua_ls", {
    Lua = {
      diagnostics = {
        enable = true,
        globals = { "vim" },
      },
      filetypes = { "lua" },
      runtime = {
        path = vim.split(package.path, ";"),
        version = "LuaJIT",
      },
      telemetry = {
        enable = false,
      },
      workspace = {
        library = vim.api.nvim_get_runtime_file("", true),
        checkThirdParty = false,
      },
    },
  })

  -- Requires vscode-langservers-extracted, which includes ESLint LSP:
  --
  -- npm install --global vscode-langservers-extracted@4.8.0
  configLsp("eslint", { workingDirectories = { mode = "auto" }, })

  -- TODO: GraphQL LSP
  -- TODO: Java LSP

  -- Manually trigger autocmd here since we have already triggered one if opening a file directly
  vim.api.nvim_exec_autocmds("FileType", {})
end

return M
