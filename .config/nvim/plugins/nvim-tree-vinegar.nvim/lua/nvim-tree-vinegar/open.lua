local M = {}

function M.split(filename)
  vim.cmd("split " .. vim.fn.fnameescape(filename))
end

function M.vsplit(filename)
  vim.cmd("vsplit " .. vim.fn.fnameescape(filename))
end

return M
