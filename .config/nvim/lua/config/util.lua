
local M = {}

-- Requires the following module structure:
-- { keymap = {}, keys = {} }
function M.addKey(module, mode, lhs, rhs, opts)
  if mode ~= nil and mode ~= "" then
    table.insert(module.keys, {mode, lhs})
  else
    table.insert(module.keys, lhs)
  end

  table.insert(module.keymap, {mode, lhs, rhs, opts})
end

function M.registerModuleKeymap(module)
  for _, map in pairs(module.keymap) do
    vim.keymap.set(map[1], map[2], map[3], map[4] or {})
  end
end

return M
