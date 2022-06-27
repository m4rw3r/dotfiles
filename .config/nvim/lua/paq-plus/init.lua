
local M = {}
local log = {}
local defaults = {
  pluginPath = vim.fn.stdpath("data") .. "/site/pack/paqs",
  log = {
    file = vim.fn.stdpath("data") .. "/paq-plus.log",
    console = false,
    debug = false,
  },
}
local options = vim.deepcopy(defaults)
local logfile = nil

function log.write(level, msg)
  print(options.log.file)
  if not logfile then
    logfile = io.open(options.log.file, "a+")
  end

  logfile:write(string.format("[%s] %s: %s\n", os.date(), level, msg))
  logfile:flush()
end

function log.debug(msg)
  if not options.log or not options.log.debug then
    return
  end

  if options.log and options.log.console then
    print("[DEBUG] paq+: " .. msg)
  end

  log.write("DEBUG", msg)
end

function log.error(msg)
  if not options.log then
    return
  end

  if options.log.console then
    print("[ERROR] paq+: " .. msg)
  end

  log.write("error", msg)
end

local function isLocal(spec)
  return string.sub(spec[1], 1, 1) == "."
end

local function pluginPath(spec)
  if isLocal(spec) then
    -- Drop any trailing slashes, also remove the leading .
    return vim.fn.stdpath("config") .. (string.sub(spec[1], -1) == "/" and string.sub(spec[1], 2, -1) or string.sub(spec[1], 2))
  else
    return options.pluginPath .. (spec.opt and "/opt/" or "/start/") .. spec.name
  end
end

local function isInstalled(spec)
  return vim.fn.isdirectory(pluginPath(spec)) ~= 0
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

  -- TODO: Deduplicate and merge, since requires can be in conflict
  if specs[name] then
    log.debug(name .. " is already added, overwriting")
  end

  specs[name] = spec

  if isLocal(spec) then
    -- Local plugin
    log.debug("Added " .. name .. " as a local plugin")
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

    log.debug("Added " .. name .. " to paq")
  end

  if spec.requires then
    if type(spec.requires) == "string" then
      -- TODO: Inherit opt
      addPackage(spec.requires)
    else
      for _, dep in pairs(spec.requires) do
        -- TODO: Inherit opt
        addPackage(dep)
      end
    end
  end
end

local function registerKeys(spec)
  if not spec.keys or vim.tbl_count(spec.keys) == 0 then
    return
  end

  log.debug("Registering keys on demand for plugin " .. spec.name)

  for _, key in pairs(spec.keys) do
    if type(key) == "table" and vim.tbl_count(key) >= 3 then
      vim.keymap.set(key[1], key[2], key[3], key[4] or {})
    end
  end
end

local function registerCmds(spec)
  if not spec.cmds or vim.tbl_count(spec.cmds) == 0 then
    return
  end

  log.debug("Registering commands on demand for plugin " .. spec.name)

  for _, cmd in pairs(spec.cmds) do
    if type(cmd) == "table" and vim.tbl_count(cmd) >= 2 then
      vim.api.nvim_create_user_command(cmd[1], cmd[2], cmd[3] or {})
    end
  end
end

local function lazyLoad(spec)
  if spec.loaded then
    return
  end

  spec.loaded = true

  if isInstalled(spec) then
    for _, name in pairs(spec.wants or {}) do
      if specs[name] then
        log.debug("Lazy plugin " .. spec.name .. " wants plugin " .. name)

        lazyLoad(specs[name])
      else
        log.error("Lazy plugin " .. spec.name .. " wants missing plugin '" .. name)
      end
    end

    if not isLocal(spec) then
      log.debug("Lazy-loading plugin " .. spec.name)

      vim.cmd("packadd " .. spec.name)
    else
      log.debug("Lazy-loading local plugin " .. spec.name)

      vim.o.runtimepath = vim.o.runtimepath .. "," .. vim.fn.escape(pluginPath(spec), '\\,')
    end

    if spec.config then
      log.debug("Configuring plugin " .. spec.name)

      spec.config()
    end

    registerKeys(spec)
    registerCmds(spec)

    log.debug("Finished lazy-loading " .. spec.name)
  else
    log.error("Failed to lazy-load " .. spec.name .. ", plugin not installed")
  end

  -- TODO: Load after?
end

-- FIXME: events
-- FIXME: filetypes
local function lazyRegisterCommands(spec)
  if not spec.cmd or vim.tbl_count(spec.cmd) == 0 then
    return
  end

  log.debug("Registering lazy-loading commands for plugin " .. spec.name)

  for _, cmd in pairs(spec.cmd or {}) do
    if type(cmd) == "string" then
      cmd = { cmd }
    end

    local called = false
    -- Reuse command configuration if we have one
    local opts = vim.deepcopy(cmd[3]) or {
      -- We have to allow all of these just in case since we do not know
      bang = true,
      nargs = "*",
      range = true,
      complete = "file",
    }

    if opts.desc then
      opts.desc = opts.desc .. ", lazy-load wrapper for plugin " .. spec.name
    else
      opts.desc = "Lazy-load wrapper for plugin " .. spec.name
    end

    vim.api.nvim_create_user_command(
      cmd[1],
      function(cause)
        -- Sanity check to avoid loops
        if called then
          return log.error("No plugin registered command " .. cmd[1])
        end

        called = true

        lazyLoad(spec)

        local lines = cause.line1 == cause.line2 and '' or (cause.line1 .. ',' .. cause.line2)

        -- Reconstruct the command
        vim.cmd(string.format('%s %s%s%s %s', cause.mods or '', lines, cmd[1], cause.bang and "!" or "", cause.args))
      end,
      opts
    )
  end
end

local function lazyRegisterKeys(spec)
  if not spec.keys or vim.tbl_count(spec.keys) == 0 then
    return
  end

  log.debug("Registering lazy-loading keys for plugin " .. spec.name)

  for _, key in pairs(spec.keys or {}) do
    local called = false

    if type(key) == "string" then
      key = { "", key }
    end

    -- Reuse command configuration if we have one
    local opts = vim.deepcopy(key[4]) or {}

    if opts.desc then
      opts.desc = opts.desc .. ", lazy-load wrapper for plugin " .. spec.name
    else
      opts.desc = "Lazy-load wrapper for plugin " .. spec.name
    end

    vim.keymap.set(
      key[1],
      key[2],
      function()
        -- Sanity check to avoid loops
        if called then
          return log.error("No plugin registered keybind " .. key[2])
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
      opts
    )
  end
end

local function loadPackage(spec)
  if spec.opt then
    lazyRegisterKeys(spec)
    lazyRegisterCommands(spec)
  elseif spec.config then
    if isInstalled(spec) then
      log.debug("Configuring " .. spec.name)

      spec.config()
    else
      log.error("Failed to configure " .. spec.name .. ", plugin not installed")
    end
  end
end

function M.reset()
  specs = {}
  packages = {}
  options = vim.deepcopy(defaults)
end

-- TODO: Parameters (paq options)
-- Bootstraps paq-nvim if not already installed
function M.bootstrap(opts)
  options = vim.tbl_deep_extend("force", options, opts or {})

  local ok, paq = pcall(require, "paq")
  if not ok then
    if options.before then
      options.before()
    end

    -- Bootstrap paq-nvim
    local install_path = pluginLocationPath .. "/start/paq-nvim"

    if vim.fn.isdirectory(install_path) == 0 then
      vim.fn.system({"git", "clone", "https://github.com/savq/paq-nvim.git", install_path})
      vim.cmd("packadd paq")
    end

    require("paq")

    if options.after then
      options.after()
    end
  end
end

function M.init(fn)
  log.debug("Loading paq")

  local paq = require("paq")

  fn(addPackage)

  log.debug("Registering paq packages")

  paq(packages)

  log.debug("Done registering paq packages")
end

function M.load()
  log.debug("Loading packages")

  for _, spec in pairs(specs) do
    loadPackage(spec)
  end
end

return M
