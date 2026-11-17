-- Shared dashboard state, constants and the on-disk cache (stdpath('state')/dashboard.json).
-- Every module holds this same table, so replacing a field (state.data = ...) is seen by all of them.
local M = {
  REFRESH_AFTER = 12 * 3600, -- seconds before the cache is refreshed in the background
  MAX_LIST = 5, -- entries shown per section before "+N more"
  data = {},
  running = false,
  buf = nil,
  win = nil,
  marks = {},
  targets = {},
  updating = {},
}

local CACHE_FILE = vim.fn.stdpath 'state' .. '/dashboard.json'

function M.load()
  local ok, data = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(CACHE_FILE), '\n'))
  end)
  M.data = (ok and type(data) == 'table') and data or {}
  if type(M.data.mason) == 'table' and type(M.data.mason[1]) ~= 'table' and #M.data.mason > 0 then
    M.data.mason, M.data.checked = nil, nil -- older cache format: force a refresh
  end
end

function M.save()
  pcall(vim.fn.writefile, { vim.json.encode(M.data) }, CACHE_FILE)
end

return M
