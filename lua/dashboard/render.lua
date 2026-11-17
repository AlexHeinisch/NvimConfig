-- Builds the dashboard buffer from state.data: content rows, logo, centring, highlights, cursor.
local state = require 'dashboard.state'
local logo = require 'dashboard.logo'
local actions = require 'dashboard.actions'
local refresh = require 'dashboard.refresh'
local M = {}

local function ago(ts)
  local s = os.time() - ts
  if s < 90 then
    return 'just now'
  elseif s < 5400 then
    return ('%d min ago'):format(math.floor(s / 60 + 0.5))
  elseif s < 129600 then
    return ('%d h ago'):format(math.floor(s / 3600 + 0.5))
  end
  return ('%d days ago'):format(math.floor(s / 86400 + 0.5))
end

---@param items string[]
---@return string[] # at most state.MAX_LIST entries plus a "+N more" line
local function capped(items)
  local out = {}
  for i = 1, math.min(#items, state.MAX_LIST) do
    out[i] = items[i]
  end
  if #items > state.MAX_LIST then
    out[#out + 1] = ('+%d more'):format(#items - state.MAX_LIST)
  end
  return out
end

local function harpoon_marks()
  local ok, list = pcall(function()
    return require('harpoon'):list()
  end)
  if not ok or not list then
    return {}
  end
  return list:display()
end

function M.render()
  local buf, win = state.buf, state.win
  if not (buf and vim.api.nvim_buf_is_valid(buf) and win and vim.api.nvim_win_is_valid(win)) then
    return
  end

  -- Content rows are left-aligned inside one centred block: { text, hl, target }
  local rows = {}
  local function add(text, hl, target)
    rows[#rows + 1] = { text = text, hl = hl, target = target }
  end
  local function status(ok, text, target)
    add((ok and '✔ ' or '● ') .. text, ok and 'DiagnosticOk' or 'DiagnosticWarn', target)
  end
  -- Every line of a group runs the same action; `key` stays stable so the selection survives redraws.
  local function detail(items, hl, key, run)
    for i, item in ipairs(capped(items)) do
      add('    ' .. item, hl or 'Comment', { key = key .. ':' .. i, run = run })
    end
  end

  local d = state.data

  -- Harpoon
  state.marks = harpoon_marks()
  add('Harpoon · ' .. vim.fn.fnamemodify(vim.uv.cwd() or '', ':t'), 'Title', { key = 'harpoon', run = actions.open_harpoon_menu })
  if #state.marks == 0 then
    add('  no marks in this project', 'Comment')
  end
  for i, mark in ipairs(state.marks) do
    add(('  %d  %s'):format(i, mark), 'Normal', {
      key = 'mark:' .. i,
      run = function()
        vim.cmd.edit(vim.fn.fnameescape(mark))
      end,
    })
  end
  add ''

  -- Health
  add('Health', 'Title')
  if state.running then
    add('  … checking', 'Comment')
  end
  if not d.checked then
    if not state.running then
      add('  not checked yet (press r)', 'Comment')
    end
  else
    local plugins = d.plugins or {}
    if #plugins == 0 then
      status(true, 'plugins up to date', { key = 'plugins', run = actions.open_updates })
    else
      status(false, ('%d plugin%s with updates'):format(#plugins, #plugins == 1 and '' or 's'), { key = 'plugins', run = actions.open_updates })
      detail(plugins, nil, 'plugins', actions.open_updates)
    end

    local commits = d.intellij or {}
    if #commits == 0 then
      status(true, 'intellij-lsp up to date', {
        key = 'intellij',
        run = function()
          vim.cmd 'checkhealth intellij-lsp'
        end,
      })
    else
      status(false, ('intellij-lsp: %d new commit%s'):format(#commits, #commits == 1 and '' or 's'), { key = 'intellij', run = actions.show_intellij_log })
      detail(commits, nil, 'intellij', actions.show_intellij_log)
    end

    local mason = d.mason or {}
    if d.mason_failed then
      status(false, 'mason: registry check failed', {
        key = 'mason',
        run = function()
          vim.cmd 'Mason'
        end,
      })
    elseif #mason == 0 then
      status(true, 'mason packages up to date', {
        key = 'mason',
        run = function()
          vim.cmd 'Mason'
        end,
      })
    else
      status(false, ('%d mason package%s with updates'):format(#mason, #mason == 1 and '' or 's'), {
        key = 'mason',
        run = function()
          local names = {}
          for _, entry in ipairs(state.data.mason or {}) do
            table.insert(names, entry.name)
          end
          actions.update_mason(names)
        end,
      })
      for _, entry in ipairs(mason) do
        local mark = state.updating[entry.name]
        local suffix = mark == 'running' and '  updating…' or mark == 'failed' and '  ✗ failed' or ''
        add(('    %s %s → %s%s'):format(entry.name, entry.current, entry.latest, suffix), mark == 'failed' and 'DiagnosticError' or 'Comment', {
          key = 'mason:' .. entry.name,
          run = function()
            actions.update_mason { entry.name }
          end,
        })
      end
    end

    local nvim = d.nvim
    if nvim then
      local release = function()
        actions.open_release(nvim.latest or nvim.current)
      end
      if nvim.failed then
        status(false, 'neovim: release check failed', { key = 'nvim', run = refresh.refresh })
      elseif nvim.latest then
        status(false, ('neovim update: %s → %s'):format(nvim.current, nvim.latest), { key = 'nvim', run = release })
      else
        status(true, ('neovim %s is the latest release'):format(nvim.current), { key = 'nvim', run = release })
      end
    end

    local health = d.health
    if health then
      if health.ok then
        status(true, 'config check passed', { key = 'health', run = actions.run_check })
      else
        add('✗ config check failed', 'DiagnosticError', { key = 'health', run = actions.run_check })
        detail(health.lines or {}, 'DiagnosticError', 'health', actions.run_check)
      end
    end
  end
  add ''

  -- Footer
  add(('init %.0f ms · %d plugins'):format(vim.g.init_ms or 0, #vim.pack.get(nil, { info = false })), 'Comment')
  if d.checked then
    add('checked ' .. ago(d.checked) .. ' · press <CR> to refresh', 'Comment', { key = 'refresh', run = refresh.refresh })
  end
  add ''
  add('<CR> runs the action of a line · 1-9 open a harpoon file · r refresh · u update plugins', 'Comment')

  -- Layout: logo and version centred on top, then the content block; all centred horizontally
  -- and vertically.
  local width, height = vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win)
  local logo, logo_segments = logo.rows(width)
  local logo_width = vim.fn.strdisplaywidth(logo[1])
  local version = ('v%d.%d.%d'):format(vim.version().major, vim.version().minor, vim.version().patch)
  local block_width = 0
  for _, row in ipairs(rows) do
    block_width = math.max(block_width, vim.fn.strdisplaywidth(row.text))
  end
  local function pad_for(w)
    return (' '):rep(math.max(0, math.floor((width - w) / 2)))
  end
  local block_pad, logo_pad = pad_for(block_width), pad_for(logo_width)

  local lines, hls, targets = {}, {}, {}
  for _ = 1, math.max(0, math.floor((height - (#logo + 3 + #rows)) / 2)) do
    lines[#lines + 1] = ''
  end
  for i, row in ipairs(logo) do
    lines[#lines + 1] = logo_pad .. row
    local segs = {}
    for _, seg in ipairs(logo_segments[i]) do
      segs[#segs + 1] = { #logo_pad + seg[1], #logo_pad + seg[2], seg[3] }
    end
    hls[#lines] = segs
  end
  local version_pad = pad_for(vim.fn.strdisplaywidth(version))
  lines[#lines + 1] = version_pad .. version
  hls[#lines] = { { #version_pad, #version_pad + #version, 'DashboardVersion' } }
  lines[#lines + 1] = ''
  lines[#lines + 1] = ''
  for _, row in ipairs(rows) do
    lines[#lines + 1] = row.text == '' and '' or block_pad .. row.text
    if row.hl then
      hls[#lines] = { { #block_pad, #lines[#lines], row.hl } }
    end
    targets[#lines] = row.target
  end
  state.targets = targets
  state.col = #block_pad

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false

  local ns = vim.api.nvim_create_namespace 'custom-dashboard'
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for lnum, segs in pairs(hls) do
    for _, seg in ipairs(segs) do
      vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, seg[1], { end_col = seg[2], hl_group = seg[3] })
    end
  end

  -- Keep the cursor on the same entry as before (or the first one on the first render).
  local want = state.selected or (#state.marks > 0 and 'mark:1' or nil)
  local first, found
  for lnum = 1, #lines do
    local t = targets[lnum]
    if t then
      first = first or lnum
      if want and t.key == want then
        found = lnum
      end
    end
  end
  local lnum = found or first
  if lnum then
    vim.api.nvim_win_set_cursor(win, { lnum, state.col })
    state.selected = targets[lnum].key
  end
end

return M
