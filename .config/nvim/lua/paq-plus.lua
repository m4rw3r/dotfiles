--[[
Paq-Plus Plugin Manager for Neovim

Manages plugin installation and lazy loading through paq-nvim integration
Provides advanced configuration options and logging capabilities
]]

---@class PaqPlusLogOptions
---@field file string|nil
---@field console boolean|nil
---@field debug boolean|nil

---@class PaqPlusOptions
---@field pluginPath string|nil
---@field log PaqPlusLogOptions|nil
---@field before (fun(): nil)|nil
---@field after (fun(): nil)|nil

---@type PaqPlusOptions
local defaults = {
  pluginPath = vim.fn.stdpath("data") .. "/site/pack/paqs",
  log = {
    file = vim.fn.stdpath("data") .. "/paq-plus.log",
    console = false,
    debug = false,
  },
}

---@type PaqPlusOptions
local options = vim.deepcopy(defaults)
---@type file*?
local logfile = nil
---@class Log
---@field write fun(level: string, msg: string): nil
---@field debug fun(msg: string): nil
---@field error fun(msg: string): nil
local log = {}

---@param level string
---@param msg string
function log.write(level, msg)
  if not logfile then
    local err

    logfile, err = io.open(options.log.file, "a+")

    if logfile == nil then
      print("PaqPlus: Error opening log-file: '" .. err .. "'")

      return
    end
  end

  logfile:write(string.format("[%s] %s: %s\n", os.date(), level, msg))
  logfile:flush()
end


---@param msg string
function log.debug(msg)
  if not options.log or not options.log.debug then
    return
  end

  if options.log and options.log.console then
    print("[DEBUG] paq+: " .. msg)
  end

  log.write("DEBUG", msg)
end

---@param msg string
function log.error(msg)
  if not options.log then
    return
  end

  if options.log.console then
    print("[ERROR] paq+: " .. msg)
  end

  log.write("error", msg)
end

---@param spec PaqPlusPluginSpec
---@return boolean
local function isLocal(spec)
  return string.sub(spec[1], 1, 1) == "."
end

---@param spec PaqPlusPluginSpec
---@return string
local function pluginPath(spec)
  if isLocal(spec) then
    -- Drop any trailing slashes, also remove the leading .
    return vim.fn.stdpath("config") .. (string.sub(spec[1], -1) == "/" and string.sub(spec[1], 2, -1) or string.sub(spec[1], 2))
  else
    return options.pluginPath .. (spec.opt and "/opt/" or "/start/") .. spec.name
  end
end

---@param spec PaqPlusPluginSpec
---@return boolean
local function isInstalled(spec)
  return vim.fn.isdirectory(pluginPath(spec)) ~= 0
end

---@class PaqPlusCmd
---@field [1] string
---@field [2] string|fun(args: vim.api.keyset.create_user_command.command_args):nil
---@field [3] vim.api.keyset.user_command

---@class PaqPlusKey
---@field [1] string
---@field [2] string
---@field [3] string|fun():nil
---@field [4] vim.keymap.set.Opts?

---@class PaqPlusPlugin
---@field [1] string
---@field name string|nil
---@field as string|nil
---@field opt boolean|nil
---@field requires string|string[]|nil
---@field branch string|nil
---@field pin boolean|nil
---@field build string|nil
---@field url string|nil
---@field keys PaqPlusKey[]|nil
---@field cmds PaqPlusCmd[]|nil
---@field config (fun(): nil)|nil
---@field wants string[]|nil

---@class PaqPlusPluginSpec
---@field [1] string
---@field name string
---@field as string
---@field loaded boolean
---@field opt boolean
---@field requires string[]
---@field branch string|nil
---@field pin boolean|nil
---@field build string|nil
---@field url string|nil
---@field keys PaqPlusKey[]
---@field cmds PaqPlusCmd[]
---@field config fun(): nil
---@field wants string[]

---@class PaqSpec
---@field [1] string
---@field as string
---@field opt boolean
---@field branch string|nil
---@field pin string|nil
---@field build string|nil
---@field url string|nil

---@type table<string, PaqPlusPluginSpec>
local specs = {}
---@type PaqSpec[]
local packages = {}

local function noop()
end

--- Normalize plugin spec to consistent format
---@param spec string|PaqPlusPlugin
---@return PaqPlusPluginSpec
local function normalizeSpec(spec)
  if type(spec) == "string" then
    spec = { spec }
  end

  return {
    spec[1],
    name = spec.as or spec[1]:match("/([%w-_.]+)$"),
    loaded = not spec.opt,
    opt = spec.opt,
    requires = type(spec.requires) == "string" and { spec.requires } or spec.requires or {},
    as = spec.as,
    branch = spec.branch,
    pin = spec.pin,
    build = spec.build,
    url = spec.url,
    keys = spec.keys or {},
    cmds = spec.cmds or {},
    config = spec.config or noop,
    wants = spec.wants or {},
  }
end

--- Add plugin to registry with dependency resolution
---@param pkg string|PaqPlusPlugin
local function addPackage(pkg)
  local spec = normalizeSpec(pkg)

  -- TODO: Deduplicate and merge, since requires can be in conflict
  if specs[spec.name] then
    log.debug(spec.name .. " is already added, overwriting")
  end

  specs[spec.name] = spec

  if isLocal(spec) then
    -- Local plugin
    log.debug("Added " .. spec.name .. " as a local plugin")
  else
    table.insert(packages, {
      spec[1],
      as = spec.as,
      opt = spec.opt,
      branch = spec.branch,
      pin = spec.pin,
      build = spec.build,
      url = spec.url,
    })

    log.debug("Added " .. spec.name .. " to paq")
  end

  -- FIXME: Propagate and merge requires properly, and skip the use of wants
  if spec.requires then
    for _, val in pairs(spec.requires) do
      local dep = normalizeSpec(val)

      -- We cannot overwrite laziness if it is already set as eager elsewhere
      -- Instead a manual add of the package will change eager to lazy
      dep.opt = spec[dep.name] and spec[dep.name].opt or spec.opt

      addPackage(dep)
    end
  end
end

---@param spec PaqPlusPluginSpec
local function registerKeys(spec)
  if vim.tbl_count(spec.keys) == 0 then
    return
  end

  log.debug("Registering keys for plugin " .. spec.name)

  for _, key in pairs(spec.keys) do
    vim.keymap.set(key[1], key[2], key[3], key[4] or {})
  end
end

---@param spec PaqPlusPluginSpec
local function registerCmds(spec)
  if vim.tbl_count(spec.cmds) == 0 then
    return
  end

  log.debug("Registering commands on demand for plugin " .. spec.name)

  for _, cmd in pairs(spec.cmds) do
    vim.api.nvim_create_user_command(cmd[1], cmd[2], cmd[3] or {})
  end
end

--- Lazy-load plugin when triggered
---@param spec PaqPlusPluginSpec
local function lazyLoad(spec)
  if spec.loaded then
    return
  end

  spec.loaded = true

  if not isInstalled(spec) then
    log.error("Failed to lazy-load " .. spec.name .. ", plugin not installed")

    return
  end

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

  -- TODO: Load after?
end

-- FIXME: events
-- FIXME: filetypes
---@param spec PaqPlusPluginSpec
local function lazyRegisterCommands(spec)
  if not spec.cmds or vim.tbl_count(spec.cmds) == 0 then
    return
  end

  log.debug("Registering lazy-loading commands for plugin " .. spec.name)

  for _, cmd in pairs(spec.cmds or {}) do
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

---@param spec PaqPlusPluginSpec
local function lazyRegisterKeys(spec)
  if vim.tbl_count(spec.keys) == 0 then
    return
  end

  log.debug("Registering lazy-loading keys for plugin " .. spec.name)

  for _, key in pairs(spec.keys or {}) do
    local called = false

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
          extra = extra .. (type(c) == "number" and vim.fn.nr2char(c) or c)
        end

        local escaped_keys = vim.api.nvim_replace_termcodes(key[2] .. extra, true, true, true)

        vim.api.nvim_feedkeys(escaped_keys, "m", true)
      end,
      opts
    )
  end
end

local function loadPackage(spec)
  if not isInstalled(spec) then
    log.error("Failed to configure " .. spec.name .. ", plugin not installed")

    return
  end

  if spec.opt then
    lazyRegisterKeys(spec)
    lazyRegisterCommands(spec)
  elseif spec.config then
    log.debug("Configuring " .. spec.name)

    spec.config()

    registerKeys(spec)
    registerCmds(spec)
  end
end

---@class PaqPlus
---@field reset fun(): nil
---@field bootstrap fun(opts: PaqPlusOptions): nil
---@field init fun(fn: fun(add: fun(spec: PaqPlusPlugin|string)): nil): nil
---@field load fun(): nil
local M = {}

--- Reset all internal state and reapply defaults
function M.reset()
  specs = {}
  packages = {}
  options = vim.deepcopy(defaults)
end

--- Bootstrap paq-nvim if not installed
---@param opts PaqPlusOptions
function M.bootstrap(opts)
  options = vim.tbl_deep_extend("force", options, opts or {})

  local ok, paq = pcall(require, "paq")
  if not ok then
    if options.before then
      options.before()
    end

    -- Bootstrap paq-nvim
    local install_path = options.pluginPath .. "/start/paq-nvim"

    if vim.fn.isdirectory(install_path) == 0 then
      vim.fn.system({"git", "clone", "https://github.com/savq/paq-nvim.git", install_path})
      vim.cmd("packadd paq-nvim")
    end

    require("paq")

    if options.after then
      options.after()
    end
  end
end

--- Register plugins and configurations
---@param fn fun(add: fun(spec: PaqPlusPlugin|string)): nil
function M.init(fn)
  log.debug("Loading paq")

  local paq = require("paq")

  fn(addPackage)

  log.debug("Registering paq packages")

  paq(packages)

  log.debug("Done registering paq packages")

  vim.schedule(M.load)
end

--- Load and configure all registered plugins
function M.load()
  log.debug("Loading packages")

  for _, spec in pairs(specs) do
    loadPackage(spec)
  end

  log.debug("Done loading packages")
end

return M
