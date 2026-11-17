-- Start screen / health dashboard, shown when Neovim starts without arguments.
--
-- Sections: harpoon marks, plugin updates (vim.pack), intellij-lsp commits waiting upstream,
-- Mason package updates, and the result of scripts/check.sh. The checks hit the network, so the
-- screen draws instantly from a cache (stdpath('state')/dashboard.json) and refreshes it in the
-- background when it is older than REFRESH_AFTER, or when you press `r` on the dashboard.
-- Buffer-local keys: <CR> runs the action of the line under the cursor (see render), 1-9 open a
-- harpoon file, u reviews plugin updates, r refreshes.
--
-- Modules: state (shared state + cache), logo, render (builds the buffer), refresh (async checks),
-- actions (what <CR> does). This file owns the window, buffer-local keys and setup().
local state = require 'dashboard.state'
local logo = require 'dashboard.logo'
local actions = require 'dashboard.actions'
local render = require 'dashboard.render'
local refresh = require 'dashboard.refresh'
local M = {}

local function open_mark(i)
  local mark = state.marks[i]
  if mark then
    vim.cmd.edit(vim.fn.fnameescape(mark))
  end
end

local function activate()
  local target = state.targets[vim.api.nvim_win_get_cursor(0)[1]]
  if target and target.run then
    target.run()
  end
end

local function show()
  local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  state.buf, state.win = buf, win

  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'dashboard'

  local saved = {}
  for _, opt in ipairs { 'number', 'relativenumber', 'cursorline', 'list', 'signcolumn', 'foldenable', 'winhighlight' } do
    saved[opt] = vim.wo[win][opt]
  end
  vim.wo[win].number, vim.wo[win].relativenumber = false, false
  vim.wo[win].cursorline, vim.wo[win].list = true, false
  vim.wo[win].winhighlight = 'CursorLine:DashboardSelected'
  vim.wo[win].signcolumn, vim.wo[win].foldenable = 'no', false

  -- Put the window options back once another buffer takes over this window.
  vim.api.nvim_create_autocmd('BufWinLeave', {
    buffer = buf,
    once = true,
    callback = function()
      if vim.api.nvim_win_is_valid(win) then
        for opt, value in pairs(saved) do
          vim.wo[win][opt] = value
        end
      end
    end,
  })

  local function map(lhs, rhs)
    vim.keymap.set('n', lhs, rhs, { buffer = buf, nowait = true, silent = true })
  end
  for i = 1, 9 do
    map(tostring(i), function()
      open_mark(i)
    end)
  end
  map('<CR>', activate)
  map('r', refresh.refresh)
  map('u', actions.open_updates)

  -- Lock the cursor to the selectable lines (marks, Mason entries), at the start of their text.
  vim.api.nvim_create_autocmd('CursorMoved', {
    buffer = buf,
    callback = function()
      local lnum, col = unpack(vim.api.nvim_win_get_cursor(0))
      local prev = state.last_line or lnum
      local best
      if state.targets[lnum] then
        best = lnum
      else
        local nearest, nearest_dir
        for l in pairs(state.targets) do
          local dist = math.abs(l - lnum)
          local in_dir = (lnum >= prev and l > lnum) or (lnum < prev and l < lnum)
          if not nearest or (in_dir and not nearest_dir) or (in_dir == nearest_dir and dist < math.abs(nearest - lnum)) then
            nearest, nearest_dir = l, in_dir
          end
        end
        best = nearest
      end
      if best and (best ~= lnum or col ~= state.col) then
        vim.api.nvim_win_set_cursor(0, { best, state.col })
      end
      state.last_line = best or lnum
      if best then
        state.selected = state.targets[best].key
      end
    end,
  })

  vim.api.nvim_create_autocmd({ 'VimResized', 'WinResized' }, {
    group = vim.api.nvim_create_augroup('custom-dashboard-resize', { clear = true }),
    callback = render.render,
  })

  render.render()
  if not state.data.checked or os.time() - state.data.checked > state.REFRESH_AFTER then
    refresh.refresh()
  end
end

function M.setup()
  state.load()
  logo.define_highlights()
  vim.api.nvim_create_autocmd(
    'ColorScheme',
    { group = vim.api.nvim_create_augroup('custom-dashboard-colors', { clear = true }), callback = logo.define_highlights }
  )
  vim.api.nvim_create_user_command('Dashboard', function()
    vim.cmd 'enew'
    show()
  end, { desc = 'Open the dashboard' })
  vim.api.nvim_create_autocmd('VimEnter', {
    group = vim.api.nvim_create_augroup('custom-dashboard', { clear = true }),
    desc = 'Show the dashboard when started without arguments',
    callback = function()
      -- Skip headless runs (scripts/check.sh), file arguments, stdin and non-empty buffers.
      if #vim.api.nvim_list_uis() == 0 or vim.fn.argc() > 0 then
        return
      end
      if vim.api.nvim_buf_get_name(0) ~= '' or vim.bo.modified or vim.fn.line2byte(vim.fn.line '$') ~= -1 then
        return
      end
      show()
    end,
  })
end

return M
