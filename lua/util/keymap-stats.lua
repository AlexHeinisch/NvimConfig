-- Tracks how often you use your keymaps, so you can review your habits.
--
-- How it works:
--   * `setup()` wraps `vim.keymap.set` (call it before any plugin loads). Every mapping
--     that has a `desc` gets a counter. That includes lazy.nvim `keys`, LSP on_attach maps
--     and plugin maps defined via vim.keymap.set.
--   * Keys typed by hand in normal mode are tallied too (`vim.on_key`). Those counts include
--     keys typed as part of a mapping (e.g. <Space>, s, f for <leader>sf).
--   * Counts are merged into stdpath('data')/keymap-stats.json every 5 minutes, on focus
--     loss and on exit, so several Neovim instances can share the file.
--
-- Commands:
--   :KeymapReport      write a markdown report (most used, never used, raw keystrokes) and open it
--   :KeymapReport!     same, then copy a ready-made prompt (report reference + question) to the clipboard for a coding agent
--   :KeymapStatsReset  delete all collected data
-- See also `:Hardtime report` (hardtime.nvim) for repeated-motion habits.
local M = {}

local data_file = vim.fn.stdpath 'data' .. '/keymap-stats.json'
local report_file = vim.fn.stdpath 'data' .. '/keymap-report.md'

local pending = { maps = {}, keys = {} } -- deltas since the last flush
local known = {} -- id -> desc for every tracked mapping defined this session (written on each flush)
local last_hit = {}
local FORGET_AFTER = 60 * 24 * 3600 -- a defined-but-unused mapping not seen in any session for this long is dropped
local dirty = false

local function mode_str(mode)
  return type(mode) == 'table' and table.concat(mode, '') or mode
end

local function hit(id, desc)
  -- lazy.nvim's load-on-key stub and the real mapping fire back to back on the first
  -- press; count that as one use.
  local now = vim.uv.hrtime()
  if last_hit[id] and now - last_hit[id] < 50e6 then
    return
  end
  last_hit[id] = now
  local e = pending.maps[id] or { count = 0 }
  e.count = e.count + 1
  e.desc = desc
  e.last = os.time()
  pending.maps[id] = e
  dirty = true
end

local function read()
  local ok, lines = pcall(vim.fn.readfile, data_file)
  if not ok or #lines == 0 then
    return {}
  end
  local dok, data = pcall(vim.json.decode, table.concat(lines, '\n'))
  return (dok and type(data) == 'table') and data or {}
end

local function write(data)
  local tmp = data_file .. '.tmp'
  vim.fn.writefile({ vim.json.encode(data) }, tmp)
  vim.uv.fs_rename(tmp, data_file)
end

function M.flush()
  if not dirty then
    return
  end
  local data = read()
  data.since = data.since or os.time()
  data.maps = type(data.maps) == 'table' and data.maps or {}
  data.keys = type(data.keys) == 'table' and data.keys or {}
  data.known = type(data.known) == 'table' and data.known or {}
  data.seen = type(data.seen) == 'table' and data.seen or {}
  local now = os.time()
  for id, desc in pairs(known) do
    data.known[id] = desc
    data.seen[id] = now
  end
  -- Buffer-local maps (LSP, gitsigns) only exist in some sessions, so "defined this session" can't
  -- decide what is stale; "not defined in any session lately" can.
  for id in pairs(data.known) do
    if not data.seen[id] then
      data.seen[id] = now
    elseif now - data.seen[id] > FORGET_AFTER then
      data.known[id], data.seen[id] = nil, nil
    end
  end
  for id, e in pairs(pending.maps) do
    local d = data.maps[id] or { count = 0 }
    d.count = d.count + e.count
    d.desc, d.last = e.desc, e.last
    data.maps[id] = d
  end
  for k, n in pairs(pending.keys) do
    data.keys[k] = (data.keys[k] or 0) + n
  end
  write(data)
  pending = { maps = {}, keys = {} }
  dirty = false
end

local function wrap_keymap_set()
  local orig = vim.keymap.set
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.keymap.set = function(mode, lhs, rhs, opts)
    local desc = opts and opts.desc
    local skip = not desc or rhs == nil or rhs == '' or (type(rhs) == 'string' and (rhs:lower() == '<nop>' or opts.expr))
    if not skip then
      local id = mode_str(mode) .. ' ' .. lhs
      known[id] = desc
      if type(rhs) == 'function' then
        local f = rhs
        rhs = function(...)
          hit(id, desc)
          return f(...)
        end
      else
        -- A plain string rhs becomes an expr mapping that returns the same keys.
        local keys = rhs
        rhs = function()
          hit(id, desc)
          return keys
        end
        opts = vim.tbl_extend('force', opts, { expr = true })
        if opts.replace_keycodes == nil then
          opts.replace_keycodes = true
        end
      end
    end
    return orig(mode, lhs, rhs, opts)
  end
end

local function track_raw_keys()
  vim.on_key(function(_, typed)
    if not typed or typed == '' then
      return
    end
    if vim.api.nvim_get_mode().mode ~= 'n' then
      return
    end
    local k = vim.fn.keytrans(typed)
    pending.keys[k] = (pending.keys[k] or 0) + 1
    dirty = true
  end, vim.api.nvim_create_namespace 'keymap-stats')
end

local function fmt_time(t)
  return t and os.date('%Y-%m-%d', t) or '-'
end

local function md_escape(s)
  return (tostring(s):gsub('|', '\\|'))
end

function M.report()
  M.flush()
  local data = read()
  local maps, keys, all = data.maps or {}, data.keys or {}, data.known or {}

  local used = {}
  for id, e in pairs(maps) do
    table.insert(used, { id = id, count = e.count, desc = e.desc, last = e.last })
  end
  table.sort(used, function(a, b)
    return a.count > b.count
  end)

  local unused = {}
  for id, desc in pairs(all) do
    if not maps[id] then
      table.insert(unused, { id = id, desc = desc })
    end
  end
  table.sort(unused, function(a, b)
    return a.id < b.id
  end)

  local raw = {}
  local total = 0
  for k, n in pairs(keys) do
    table.insert(raw, { key = k, count = n })
    total = total + n
  end
  table.sort(raw, function(a, b)
    return a.count > b.count
  end)

  local out = {
    '# Keymap usage report',
    '',
    ('Tracking since %s. %d mappings used, %d defined but never used, %d normal-mode keystrokes.'):format(fmt_time(data.since), #used, #unused, total),
    '',
    'Mapping ids are `<modes> <lhs>`. `<leader>` is Space. See `:Hardtime report` for repeated-motion habits.',
    '',
    '## Mappings by use',
    '',
    '| uses | mapping | description | last used |',
    '|-----:|---------|-------------|-----------|',
  }
  for _, u in ipairs(used) do
    table.insert(out, ('| %d | `%s` | %s | %s |'):format(u.count, md_escape(u.id), md_escape(u.desc or ''), fmt_time(u.last)))
  end

  vim.list_extend(out, { '', '## Never used', '' })
  for _, u in ipairs(unused) do
    table.insert(out, ('- `%s` %s'):format(md_escape(u.id), u.desc or ''))
  end

  vim.list_extend(out, {
    '',
    '## Normal-mode keystrokes (top 60)',
    '',
    'Raw keys typed in normal mode, including keys that were part of a mapping.',
    '',
    '| key | count | share |',
    '|-----|------:|------:|',
  })
  for i = 1, math.min(60, #raw) do
    local r = raw[i]
    table.insert(out, ('| `%s` | %d | %.1f%% |'):format(md_escape(r.key), r.count, 100 * r.count / math.max(total, 1)))
  end

  vim.fn.writefile(out, report_file)
  return report_file
end

M.agent_prompt = table.concat({
  'This is a usage report of my Neovim keymaps and normal-mode keystrokes.',
  'I mainly write Java (IntelliJ LSP), use herdr, and work alongside coding agents.',
  'My config is in ~/.config/nvim. Look at it and the report, then recommend:',
  '1) built-in motions/text objects that would replace my most frequent keystroke patterns,',
  '2) mappings I never use that could be removed or rebound,',
  '3) frequently used mappings that deserve a faster key, and',
  '4) anything else that would make me faster. Keep it concrete and prioritized.',
}, ' ')

function M.setup()
  wrap_keymap_set()
  track_raw_keys()

  local group = vim.api.nvim_create_augroup('keymap-stats', { clear = true })
  vim.api.nvim_create_autocmd({ 'VimLeavePre', 'FocusLost' }, { group = group, callback = M.flush })
  local timer = vim.uv.new_timer()
  if timer then
    timer:start(5 * 60 * 1000, 5 * 60 * 1000, vim.schedule_wrap(M.flush))
  end

  vim.api.nvim_create_user_command('KeymapReport', function(cmd)
    local path = M.report()
    vim.cmd.edit(vim.fn.fnameescape(path))
    if cmd.bang then
      local prompt = '@' .. path .. ' ' .. M.agent_prompt
      vim.fn.setreg('+', prompt)
      vim.fn.setreg('"', prompt)
      vim.notify 'Report prompt copied to the clipboard; paste it into your coding agent'
    end
  end, { bang = true, desc = 'Keymap usage report (! = also copy an agent prompt to the clipboard)' })

  vim.api.nvim_create_user_command('KeymapStatsReset', function()
    pending = { maps = {}, keys = {} }
    vim.fn.delete(data_file)
    dirty = true -- re-record the mappings defined this session as "known"
    vim.notify 'Keymap stats reset'
  end, { desc = 'Delete collected keymap usage data' })
end

return M
