---@type PaqPlusPlugin
local M = {
  "folke/snacks.nvim",
  keys = {
    { "", "<C-p>", function() require("snacks").picker.smart() end, { desc = "Smart Find Files" } },
    { "", "<M-p>", function() require("snacks").picker.smart() end, { desc = "Smart Find Files, ignore", } },
    { "", "<leader>f", function() require("snacks").picker.grep() end, { desc = "Fuzzy search files" } },
    { "", "<leader>b", function() require("snacks").git.blame_line() end, { desc = "Show Git blame for line" } },
    { "", "<leader>n", function() require("snacks").notifier.show_history() end, { desc = "Show Notification History" } },
    { "", "<leader>un", function() require("snacks").notifier.hide() end, { desc = "Dismiss All Notifications" } },
    { "", "<leader>z", function() require("snacks").zen() end, { desc = "Toggle Zen Mode" } },
    { "n", "<leader>sq", function() Snacks.picker.qflist() end, { desc = "Quickfix List" } },
    { "n", "gd", function() require("snacks").picker.lsp_definitions() end, { desc = "Goto Definition" } },
    { "n", "gD", function() require("snacks").picker.lsp_declarations() end, { desc = "Goto Declaration" } },
    { "n", "gr", function() require("snacks").picker.lsp_references() end, { nowait = true, desc = "References" } },
    { "n", "gI", function() require("snacks").picker.lsp_implementations() end, { desc = "Goto Implementation" } },
    { "n", "gy", function() require("snacks").picker.lsp_type_definitions() end, { desc = "Goto T[y]pe Definition" } },
    { "n", "gai", function() require("snacks").picker.lsp_incoming_calls() end, { desc = "C[a]lls Incoming" } },
    { "n", "gao", function() require("snacks").picker.lsp_outgoing_calls() end, { desc = "C[a]lls Outgoing" } },
  },
}

function M.config()
  local snacks = require("snacks")

  snacks.setup({
    bigfile = { enabled = true },
    git = { enabled = true },
    input = { enabled = true },
    notifier = {
      enabled = true,
      top_down = false,
      timeout = 5000,
      -- Variant of minimal with icon on left
      style = function(buf, notif, ctx)
        ctx.opts.border = "none"
        local whl = ctx.opts.wo.winhighlight
        ctx.opts.wo.winhighlight = whl:gsub(ctx.hl.msg, "NormalFloat")
        local msg = vim.trim(notif.icon .. " " .. notif.msg)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(msg, "\n"))
        vim.api.nvim_buf_set_extmark(buf, ctx.ns, 0, 0, {
          virt_text = { { notif.icon, ctx.hl.icon } },
          virt_text_pos = "overlay",
        })
      end,
      -- Not taking statusline into account for some reason
      margin = { top = 0, right = 1, bottom = 2 },
    },
    picker = {
      enabled = true,
    },
    zen = { enabled = true },

    -- Disabled
    bufdelete = { enabled = false },
    dashboard = { enabled = false },
    debug = { enabled = false },
    dim = { enabled = false },
    explorer = { enabled = false },
    gh = { enabled = false },
    gitbrowse = { enabled = false },
    image = { enabled = false },
    indent = { enabled = false },
    keymap = { enabled = false },
    layout = { enabled = false },
    lazygit = { enabled = false },
    notify = { enabled = false },
    quickfile = { enabled = false },
    rename = { enabled = false },
    scope = { enabled = false },
    scroll = { enabled = false },
    statuscolumn = { enabled = false },
    terminal = { enabled = false },
    toggle = { enabled = false },
    win = { enabled = false },
    words = { enabled = false },
  })

  vim.api.nvim_create_autocmd("LspProgress", {
    ---@param ev {data: {client_id: integer, params: lsp.ProgressParams}}
    callback = function(ev)
      local spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
      vim.notify(vim.lsp.status(), "info", {
        id = "lsp_progress",
        title = "LSP Progress",
        opts = function(notif)
          notif.icon = ev.data.params.value.kind == "end" and " "
            or spinner[math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinner + 1]
        end,
      })
    end,
  })
end

return M
