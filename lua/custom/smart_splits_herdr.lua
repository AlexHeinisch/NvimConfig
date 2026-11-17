-- smart-splits.nvim backend for herdr (https://herdr.dev).
-- When Neovim reaches the edge of its own splits, focus/resize moves on to the
-- neighbouring herdr pane. The other direction (herdr pane -> Neovim) is handled
-- by ~/.config/herdr/smart-nav.sh, bound to <C-hjkl>/<A-hjkl> in herdr's config.toml.
local M = {
  name = 'herdr',
  protocol_version = '^3.0.0',
}

local function pane_id()
  local id = vim.env.HERDR_PANE_ID
  return (id ~= nil and id ~= '') and id or nil
end

---Run a herdr CLI command and return the `result` table of its JSON reply.
---@param args string[]
---@return table|nil
local function herdr(args)
  local cmd = { vim.env.HERDR_BIN_PATH or 'herdr' }
  vim.list_extend(cmd, args)
  local ok, res = pcall(function() return vim.system(cmd, { text = true }):wait(1000) end)
  if not ok or res.code ~= 0 then return nil end
  local decoded_ok, json = pcall(vim.json.decode, res.stdout)
  return decoded_ok and type(json) == 'table' and json.result or nil
end

function M.detect() return pane_id() ~= nil end

function M.move(direction)
  local r = herdr { 'pane', 'focus', '--direction', direction, '--pane', pane_id() }
  return r ~= nil and r.focus ~= nil and r.focus.changed == true
end

function M.resize(direction)
  -- herdr's --amount is a split ratio, not cells, so use herdr's default step.
  local r = herdr { 'pane', 'resize', '--direction', direction, '--pane', pane_id() }
  return r ~= nil and r.resize ~= nil and r.resize.changed == true
end

return M
