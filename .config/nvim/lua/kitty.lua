--- NeoVIM Kitty integration in lua.
---
---This module requires two kittens installed in Kitty to provide the key
---forwarding as well as the window-switching:
---
--- * ~/.config/kitty/neighboring_window_vim.py
--- * ~/.config/kitty/neighboring_window.py

---@alias KittyDirection "left"|"bottom"|"up"|"right"
---@alias VimDirection "h"|"j"|"k"|"l"

local M = {}

---Kitty always sets KITTY_INSTALLATION_DIR env-variable for integration purposes.
M.in_kitty = os.getenv("KITTY_INSTALLATION_DIR") ~= nil
---
M.listen_on = os.getenv("KITTY_LISTEN_ON")
M.enabled = M.in_kitty

---Tells kitty to swap window
---@param kittyDirection KittyDirection
function M.navigateKitty(kittyDirection)
  if M.listen_on then
    local output = vim.fn.system({"kitty", "@", "kitten", "neighboring_window.py", kittyDirection})

    return vim.v.shell_error, output
  else
    return -1, "env-var KITTY_LISTEN_ON is not set, make sure Kitty is configured using listen_on or --listen-on="

    -- BROKEN, do not use
    -- runInTty("kitty", {"@", "kitten", "neighboring_window.py", kittyDirection}, callback)
  end
end

---Wrapper around normal ":wincmd direction-key" function
---@param vimDirection VimDirection
function M.navigateVim(vimDirection)
  return vim.api.nvim_command("wincmd " .. vimDirection)
end

---Kitty-aware window-navigation
---@param vimDirection VimDirection
---@param kittyDirection KittyDirection
---@return fun() callback A callback which will attempt to navigate when triggered
function M.navigate(vimDirection, kittyDirection)
  return function()
    if M.enabled then
      local currentWindow = vim.api.nvim_win_get_number(0);
      local nextWindow = vim.fn.winnr(vimDirection);

      -- We get the current window back if there is no window in the direction we are looking
      if currentWindow == nextWindow then
        local code, output = M.navigateKitty(kittyDirection)

        if code == 0 then
          return
        end

        error(output)
        -- Fallback
      end
    end

    M.navigateVim(vimDirection)
  end
end

-- Attempts at using libUV to launch the kitten, preserving the TTY so the
-- listen_on configuration value would not need to be used.
--
-- Technically it works, but can cause VIM to hang and then crash randomly.
--
-- NeoVIM has crashed with the following error after excessive use of ctrl+hjlk
-- moving back and forth between NeoVIM and kitty windows, without releasing
-- ctrl:
--
-- handle_raw_buffer:  assertion « consumed <= input->read_stream.buffer->size » failed.
--
-- Not releasing ctrl seems to be the cause since according to
-- https://github.com/neovim/neovim/issues/13551.
-- Can possibly be related to Kitty not releasing keys for the Kitty-window
-- which lost focus.
-- But from testing it seems like kitty IS sending some focus information and
-- it works when not going through the remote control kitten, focus is properly
-- sent when movement is done through a keybind. It is not the ctrl being held
-- down while the escape sequence for the focus lost event is received, it is
-- still triggered even when using a command inside NeoVIM to swap.
-- It looks like the use of LibUV somehow prevents NeoVIM from receiving the
-- escape codes for the focus events, or possibly having some kind of
-- race-condition in regards to input.

--- Wrapper running process in LibUV with NeoVIMs stdin TTY forwarded.
--
-- Note: This function is async
--
-- Kitty requires a TTY to properly communicate with the parent terminal, and
-- it cannot be a pseudoterminal, neither vim.fn.system nor vim.fn.jobstart, or
-- vim.fn.termopen will provide the orignal TTY.
--
-- @param cmd Command
-- @param args List of command arguments
local function runInTty(cmd, args, callback)
  -- Use LibUV to manually control file descriptors
  local uv = vim.loop
  local data = {}
  -- We actually do not need to forward any of these to the Kitty process since
  -- the TTY is forwarded.
  local stdin = uv.new_pipe()
  local stdout = uv.new_pipe()
  local function onExit(code, signal)
    if callback then
      callback(code, table.concat(data, ""))
    end

    stdout:close()
  end
  local function appendData(err, chunk)
    table.insert(data, chunk)
  end

  local handle, pid = uv.spawn(cmd, {
    stdio = {
      stdin,
      stdout,
      -- Redirect stderr to stdout
      stdout,
    },
    args = args,
    -- We have to run as detached
    detached = false,
    hide = true,
  }, onExit)

  stdin:close()
  stdout:read_start(appendData)
end

return M
