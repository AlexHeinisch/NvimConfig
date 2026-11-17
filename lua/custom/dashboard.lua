-- Start screen / health dashboard, shown when Neovim starts without arguments.
--
-- Sections: harpoon marks, plugin updates (lazy.nvim), intellij-lsp commits waiting upstream,
-- Mason package updates, and the result of scripts/check.sh. The checks hit the network, so the
-- screen draws instantly from a cache (stdpath('state')/dashboard.json) and refreshes it in the
-- background when it is older than REFRESH_AFTER, or when you press `r` on the dashboard.
-- Buffer-local keys: <CR> runs the action of the line under the cursor (see render), 1-9 open a
-- harpoon file, u opens :Lazy, r refreshes.
local M = {}

local CACHE_FILE = vim.fn.stdpath 'state' .. '/dashboard.json'
local REFRESH_AFTER = 12 * 3600
local MAX_LIST = 5 -- entries shown per section before "+N more"

local state = { data = {}, running = false, buf = nil, win = nil, marks = {}, targets = {}, updating = {} }

-- [[ Cache ]]

local function load_cache()
  local ok, data = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(CACHE_FILE), '\n'))
  end)
  state.data = (ok and type(data) == 'table') and data or {}
  if type(state.data.mason) == 'table' and type(state.data.mason[1]) ~= 'table' and #state.data.mason > 0 then
    state.data.mason, state.data.checked = nil, nil -- older cache format: force a refresh
  end
end

local function save_cache()
  pcall(vim.fn.writefile, { vim.json.encode(state.data) }, CACHE_FILE)
end

-- [[ Rendering ]]

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
---@return string[] # at most MAX_LIST entries plus a "+N more" line
local function capped(items)
  local out = {}
  for i = 1, math.min(#items, MAX_LIST) do
    out[i] = items[i]
  end
  if #items > MAX_LIST then
    out[#out + 1] = ('+%d more'):format(#items - MAX_LIST)
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

-- 5x5 pixel font for the title
local GLYPHS = {
  N = { 'X...X', 'XX..X', 'X.X.X', 'X..XX', 'X...X' },
  E = { 'XXXXX', 'X....', 'XXXX.', 'X....', 'XXXXX' },
  O = { '.XXX.', 'X...X', 'X...X', 'X...X', '.XXX.' },
  V = { 'X...X', 'X...X', 'X...X', '.X.X.', '..X..' },
  I = { 'XXXXX', '..X..', '..X..', '..X..', 'XXXXX' },
  M = { 'X...X', 'XX.XX', 'X.X.X', 'X...X', 'X...X' },
}
-- Solarized accents, one per pixel row, plus a dim drop shadow. Re-applied on :colorscheme.
local LOGO_COLORS = { '#b58900', '#cb4b16', '#dc322f', '#d33682', '#6c71c4' }
local function define_highlights()
  for i, color in ipairs(LOGO_COLORS) do
    vim.api.nvim_set_hl(0, 'DashboardLogo' .. i, { fg = color, bold = true })
  end
  vim.api.nvim_set_hl(0, 'DashboardLogoShadow', { fg = '#2a4a55' })
  vim.api.nvim_set_hl(0, 'DashboardVersion', { fg = '#839496', italic = true })
  vim.api.nvim_set_hl(0, 'DashboardSelected', { bg = '#073642', bold = true })
end

---@param width integer window width; wide windows get 2-column pixels (square-looking)
---@return string[] rows, table[][] segments # text rows and per-row { start_byte, end_byte, group } runs
local function logo_rows(width)
  local scale = width >= 84 and 2 or 1
  local letters = { 'N', 'E', 'O', 'V', 'I', 'M' }
  -- Pixel grid with a one-pixel drop shadow to the bottom right.
  local grid = {}
  for r = 1, 6 do
    grid[r] = {}
  end
  local col = 0
  for _, ch in ipairs(letters) do
    for r = 1, 5 do
      for c = 1, 5 do
        if GLYPHS[ch][r]:sub(c, c) == 'X' then
          grid[r][col + c] = 'X'
        end
      end
    end
    col = col + 6
  end
  for r = 1, 5 do
    for c = 1, col do
      if grid[r][c] == 'X' and not grid[r + 1][c + 1] then
        grid[r + 1][c + 1] = grid[r + 1][c + 1] or 'S'
      end
    end
  end
  local rows, segments = {}, {}
  for r = 1, 6 do
    local text, segs = '', {}
    for c = 1, col + 1 do
      local cell = grid[r][c]
      local piece = cell == 'X' and ('█'):rep(scale) or cell == 'S' and ('░'):rep(scale) or (' '):rep(scale)
      if cell then
        table.insert(segs, { #text, #text + #piece, cell == 'X' and ('DashboardLogo' .. r) or 'DashboardLogoShadow' })
      end
      text = text .. piece
    end
    rows[r], segments[r] = text, segs
  end
  return rows, segments
end

function M.update_mason(names)
  local registry = require 'mason-registry'
  for _, name in ipairs(names) do
    if not state.updating[name] then
      state.updating[name] = 'running'
      local ok = pcall(function()
        registry.get_package(name):install({}, function(success)
          vim.schedule(function()
            if success then
              state.updating[name] = nil
              state.data.mason = vim.tbl_filter(function(entry)
                return entry.name ~= name
              end, state.data.mason or {})
              save_cache()
            else
              state.updating[name] = 'failed'
            end
            M.render()
          end)
        end)
      end)
      if not ok then
        state.updating[name] = 'failed'
      end
    end
  end
  M.render()
end

-- [[ Actions (Enter on a line) ]]

---@param title string
---@param lines string[]
local function float(title, lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = 'wipe'
  local width = math.min(100, vim.o.columns - 8)
  local height = math.min(#lines, vim.o.lines - 8)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = math.max(height, 1),
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' ' .. title .. ' ',
    title_pos = 'center',
  })
  vim.wo[win].wrap = true
  for _, key in ipairs { 'q', '<Esc>', '<CR>' } do
    vim.keymap.set('n', key, '<Cmd>close<CR>', { buffer = buf, nowait = true, silent = true })
  end
end

local function open_lazy()
  vim.cmd 'Lazy'
end

local function show_intellij_log()
  local plugin = require('lazy.core.config').plugins['intellij-lsp.nvim']
  if not plugin then
    return
  end
  vim.system({ 'git', '-C', plugin.dir, 'log', '--date=short', '--format=%h  %cd  %s%n%b', 'HEAD..origin/HEAD' }, { text = true }, function(out)
    vim.schedule(function()
      local lines = vim.split(vim.trim(out.stdout or ''), '\n')
      float('intellij-lsp.nvim: new upstream commits', lines)
    end)
  end)
end

local function run_check()
  vim.notify 'Running config check…'
  vim.system({ 'bash', vim.fn.stdpath 'config' .. '/scripts/check.sh' }, { text = true }, function(out)
    vim.schedule(function()
      local text = vim.trim((out.stdout or '') .. (out.stderr or ''))
      local lines = vim.split(text, '\n')
      state.data.health = { ok = out.code == 0, lines = out.code == 0 and {} or vim.list_slice(lines, math.max(1, #lines - MAX_LIST + 1)) }
      save_cache()
      M.render()
      float(out.code == 0 and 'config check: passed' or 'config check: FAILED', lines)
    end)
  end)
end

local function open_release(version)
  vim.ui.open('https://github.com/neovim/neovim/releases/tag/v' .. version)
end

local function open_harpoon_menu()
  vim.api.nvim_feedkeys(vim.keycode '<leader>M', 'm', false)
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
  add('Harpoon · ' .. vim.fn.fnamemodify(vim.uv.cwd() or '', ':t'), 'Title', { key = 'harpoon', run = open_harpoon_menu })
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
      status(true, 'plugins up to date', { key = 'plugins', run = open_lazy })
    else
      status(false, ('%d plugin%s with updates'):format(#plugins, #plugins == 1 and '' or 's'), { key = 'plugins', run = open_lazy })
      detail(plugins, nil, 'plugins', open_lazy)
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
      status(false, ('intellij-lsp: %d new commit%s'):format(#commits, #commits == 1 and '' or 's'), { key = 'intellij', run = show_intellij_log })
      detail(commits, nil, 'intellij', show_intellij_log)
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
          M.update_mason(names)
        end,
      })
      for _, entry in ipairs(mason) do
        local mark = state.updating[entry.name]
        local suffix = mark == 'running' and '  updating…' or mark == 'failed' and '  ✗ failed' or ''
        add(('    %s %s → %s%s'):format(entry.name, entry.current, entry.latest, suffix), mark == 'failed' and 'DiagnosticError' or 'Comment', {
          key = 'mason:' .. entry.name,
          run = function()
            M.update_mason { entry.name }
          end,
        })
      end
    end

    local nvim = d.nvim
    if nvim then
      local release = function()
        open_release(nvim.latest or nvim.current)
      end
      if nvim.failed then
        status(false, 'neovim: release check failed', { key = 'nvim', run = M.refresh })
      elseif nvim.latest then
        status(false, ('neovim update: %s → %s'):format(nvim.current, nvim.latest), { key = 'nvim', run = release })
      else
        status(true, ('neovim %s is the latest release'):format(nvim.current), { key = 'nvim', run = release })
      end
    end

    local health = d.health
    if health then
      if health.ok then
        status(true, 'config check passed', { key = 'health', run = run_check })
      else
        add('✗ config check failed', 'DiagnosticError', { key = 'health', run = run_check })
        detail(health.lines or {}, 'DiagnosticError', 'health', run_check)
      end
    end
  end
  add ''

  -- Footer
  local stats = require('lazy').stats()
  add(('startup %.0f ms · %d/%d plugins loaded'):format(stats.startuptime, stats.loaded, stats.count), 'Comment', {
    key = 'startup',
    run = function()
      vim.cmd 'Lazy profile'
    end,
  })
  if d.checked then
    add('checked ' .. ago(d.checked) .. ' · press <CR> to refresh', 'Comment', { key = 'refresh', run = M.refresh })
  end
  add ''
  add('<CR> runs the action of a line · 1-9 open a harpoon file · r refresh · u :Lazy', 'Comment')

  -- Layout: logo and version centred on top, then the content block; all centred horizontally
  -- and vertically.
  local width, height = vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win)
  local logo, logo_segments = logo_rows(width)
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
      if want and M.key(t) == want then
        found = lnum
      end
    end
  end
  local lnum = found or first
  if lnum then
    vim.api.nvim_win_set_cursor(win, { lnum, state.col })
    state.selected = M.key(targets[lnum])
  end
end

---@param target table
function M.key(target)
  return target.key
end

-- [[ Refresh (async) ]]

local function refresh()
  if state.running then
    return
  end
  state.running = true
  M.render()

  local result = { checked = os.time() }
  local pending = 4
  local function done()
    pending = pending - 1
    if pending == 0 then
      vim.schedule(function()
        state.data = result
        state.running = false
        save_cache()
        M.render()
      end)
    end
  end

  -- 1. lazy.nvim: fetch every plugin, list those behind upstream, and the new commits of intellij-lsp.
  local ok = pcall(function()
    require('lazy.manage').check({ show = false, clear = false }):wait(function()
      vim.schedule(function()
        local names, commits = {}, {}
        pcall(function()
          require('lazy.manage.checker').fast_check { report = false }
          for _, plugin in pairs(require('lazy.core.config').plugins) do
            local updates = plugin._.updates
            if updates then
              table.insert(names, plugin.name)
              if plugin.name == 'intellij-lsp.nvim' then
                local out = vim.system({ 'git', '-C', plugin.dir, 'log', '--format=%s', 'HEAD..' .. updates.to.commit }, { text = true }):wait()
                commits = vim.split(vim.trim(out.stdout or ''), '\n', { trimempty = true })
              end
            end
          end
        end)
        table.sort(names)
        result.plugins, result.intellij = names, commits
        done()
      end)
    end)
  end)
  if not ok then
    result.plugins, result.intellij = {}, {}
    done()
  end

  -- 2. Mason: refresh the registry, compare installed and latest versions.
  local mason_ok = pcall(function()
    local registry = require 'mason-registry'
    registry.update(function(success)
      vim.schedule(function()
        local outdated = {}
        if success then
          for _, pkg in ipairs(registry.get_installed_packages()) do
            local good, cur, latest = pcall(function()
              return pkg:get_installed_version(), pkg:get_latest_version()
            end)
            if good and cur and latest and cur ~= latest then
              table.insert(outdated, { name = pkg.name, current = cur, latest = latest })
            end
          end
        end
        table.sort(outdated, function(a, b)
          return a.name < b.name
        end)
        result.mason, result.mason_failed = outdated, not success
        done()
      end)
    end)
  end)
  if not mason_ok then
    result.mason, result.mason_failed = {}, true
    done()
  end

  -- 3. Latest Neovim release (GitHub). Only the public release endpoint is queried, no local data is sent.
  local curl_ok = pcall(
    vim.system,
    { 'curl', '-fsS', '--max-time', '15', '-H', 'Accept: application/vnd.github+json', 'https://api.github.com/repos/neovim/neovim/releases/latest' },
    { text = true },
    function(out)
      vim.schedule(function()
        local current = vim.version()
        local info = { current = ('%d.%d.%d'):format(current.major, current.minor, current.patch) }
        local ok, json = pcall(vim.json.decode, out.stdout or '')
        local latest = ok and type(json) == 'table' and type(json.tag_name) == 'string' and vim.version.parse(json.tag_name) or nil
        if latest then
          if vim.version.gt(latest, current) then
            info.latest = ('%d.%d.%d'):format(latest.major, latest.minor, latest.patch)
          end
        else
          info.failed = true
        end
        result.nvim = info
        done()
      end)
    end
  )
  if not curl_ok then
    result.nvim = { current = '?', failed = true }
    done()
  end

  -- 4. Config smoke test.
  local script = vim.fn.stdpath 'config' .. '/scripts/check.sh'
  local spawned = pcall(vim.system, { 'bash', script }, { text = true }, function(out)
    local text = vim.trim((out.stdout or '') .. (out.stderr or ''))
    local tail = vim.split(text, '\n', { trimempty = true })
    result.health = { ok = out.code == 0, lines = out.code == 0 and {} or vim.list_slice(tail, math.max(1, #tail - MAX_LIST + 1)) }
    done()
  end)
  if not spawned then
    done()
  end
end

M.refresh = refresh

-- [[ Window / buffer ]]

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
  map('r', refresh)
  map('u', '<Cmd>Lazy<CR>')

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
        state.selected = M.key(state.targets[best])
      end
    end,
  })

  vim.api.nvim_create_autocmd({ 'VimResized', 'WinResized' }, {
    group = vim.api.nvim_create_augroup('custom-dashboard-resize', { clear = true }),
    callback = M.render,
  })

  M.render()
  if not state.data.checked or os.time() - state.data.checked > REFRESH_AFTER then
    refresh()
  end
end

function M.setup()
  load_cache()
  define_highlights()
  vim.api.nvim_create_autocmd('ColorScheme', { group = vim.api.nvim_create_augroup('custom-dashboard-colors', { clear = true }), callback = define_highlights })
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
