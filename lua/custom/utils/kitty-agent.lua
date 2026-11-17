-- Send file / selection references from Neovim to a coding agent (claude, pi) running in
-- another kitty window, via kitty remote control (`allow_remote_control` + `listen_on`).
--
-- The agent window is found by its foreground process: any window whose command line
-- contains an executable named like one of `M.agents`. Windows in the current tab win;
-- with several candidates you pick once and the choice is remembered.
--
-- No keymaps; used by `:KeymapReport!`. Public: send_ref, send_diagnostics, prompt, focus, send_text.
local M = {}

M.agents = { 'claude', 'pi' }

local last_window_id

local function kitty(args, stdin)
  local listen = vim.env.KITTY_LISTEN_ON
  if not listen or listen == '' then
    return nil, 'KITTY_LISTEN_ON is not set (needs kitty with allow_remote_control + listen_on)'
  end
  local cmd = vim.list_extend({ 'kitty', '@', '--to', listen }, args)
  local res = vim.system(cmd, { text = true, stdin = stdin }):wait()
  if res.code ~= 0 then
    return nil, vim.trim((res.stderr or '') .. (res.stdout or ''))
  end
  return res.stdout
end

local function is_agent(window)
  for _, proc in ipairs(window.foreground_processes or {}) do
    for i = 1, math.min(#(proc.cmdline or {}), 2) do
      local name = vim.fs.basename(proc.cmdline[i])
      if vim.tbl_contains(M.agents, name) then
        return name, proc.cwd
      end
    end
  end
end

--- List agent windows, the ones in the tab that holds this Neovim first.
local function find_agents()
  local out, err = kitty { 'ls' }
  if not out then
    return nil, err
  end
  local ok, os_windows = pcall(vim.json.decode, out)
  if not ok then
    return nil, 'could not parse `kitty @ ls` output'
  end
  local self_id = tonumber(vim.env.KITTY_WINDOW_ID)
  local same_tab, other = {}, {}
  for _, osw in ipairs(os_windows) do
    for _, tab in ipairs(osw.tabs) do
      local has_self = vim.iter(tab.windows):any(function(w)
        return w.is_self or w.id == self_id
      end)
      for _, w in ipairs(tab.windows) do
        local name, cwd = is_agent(w)
        if name then
          local entry = { id = w.id, name = name, cwd = cwd or w.cwd, title = w.title, tab = tab.title }
          table.insert(has_self and same_tab or other, entry)
        end
      end
    end
  end
  return vim.list_extend(same_tab, other), nil, #same_tab
end

--- Calls `cb(agent)` with the agent window to talk to.
local function with_agent(cb)
  local agents, err, n_same_tab = find_agents()
  if not agents then
    return vim.notify('kitty-agent: ' .. err, vim.log.levels.ERROR)
  end
  if #agents == 0 then
    return vim.notify('kitty-agent: no window running ' .. table.concat(M.agents, '/') .. ' found', vim.log.levels.WARN)
  end
  for _, a in ipairs(agents) do
    if a.id == last_window_id then
      return cb(a)
    end
  end
  if #agents == 1 or n_same_tab == 1 then
    last_window_id = agents[1].id
    return cb(agents[1])
  end
  vim.ui.select(agents, {
    prompt = 'Send to which agent?',
    format_item = function(a)
      return ('%s  [%s]  %s'):format(a.name, a.tab or '?', a.title or '')
    end,
  }, function(choice)
    if choice then
      last_window_id = choice.id
      cb(choice)
    end
  end)
end

--- Path of the current file relative to the agent's cwd (absolute if outside of it).
local function file_ref(agent, l1, l2)
  local abs = vim.api.nvim_buf_get_name(0)
  if abs == '' then
    return nil
  end
  local path = (agent.cwd and vim.fs.relpath(agent.cwd, abs)) or abs
  local ref = '@' .. path
  if l1 then
    ref = ref .. (l1 == l2 and ('#L%d'):format(l1) or ('#L%d-%d'):format(l1, l2))
  end
  return ref
end

local function send(agent, text, opts)
  opts = opts or {}
  local match = { '--match', 'id:' .. agent.id }
  local _, err = kitty(vim.list_extend({ 'send-text', '--bracketed-paste=enable', '--stdin' }, match), text)
  if err then
    return vim.notify('kitty-agent: ' .. err, vim.log.levels.ERROR)
  end
  if opts.submit then
    kitty(vim.list_extend({ 'send-text', '--stdin' }, match), '\r')
  end
  if opts.focus ~= false then
    kitty(vim.list_extend({ 'focus-window' }, match))
  end
end

--- Visual selection line range, leaving visual mode. nil outside visual mode.
local function visual_range()
  local mode = vim.fn.mode()
  if not mode:match '[vV\22]' then
    return nil
  end
  local a, b = vim.fn.line 'v', vim.fn.line '.'
  vim.api.nvim_feedkeys(vim.keycode '<Esc>', 'nx', false)
  return math.min(a, b), math.max(a, b)
end

function M.send_ref()
  local l1, l2 = visual_range()
  with_agent(function(agent)
    local ref = file_ref(agent, l1, l2)
    if not ref then
      return vim.notify('kitty-agent: buffer has no file', vim.log.levels.WARN)
    end
    send(agent, ref .. ' ')
  end)
end

function M.send_diagnostics()
  local lnum = vim.fn.line '.'
  local diags = vim.diagnostic.get(0, { lnum = lnum - 1 })
  if #diags == 0 then
    return vim.notify('kitty-agent: no diagnostics on this line', vim.log.levels.INFO)
  end
  with_agent(function(agent)
    local lines = { file_ref(agent, lnum, lnum) .. ' has these diagnostics:' }
    for _, d in ipairs(diags) do
      local sev = vim.diagnostic.severity[d.severity] or '?'
      table.insert(lines, ('- [%s] %s%s'):format(sev, d.message, d.source and (' (' .. d.source .. ')') or ''))
    end
    send(agent, table.concat(lines, '\n') .. '\n')
  end)
end

function M.prompt()
  local l1, l2 = visual_range()
  with_agent(function(agent)
    vim.ui.input({ prompt = agent.name .. '> ' }, function(input)
      if not input or input == '' then
        return
      end
      local ref = file_ref(agent, l1, l2)
      send(agent, (ref and (ref .. ' ') or '') .. input, { submit = true, focus = false })
    end)
  end)
end

function M.focus()
  with_agent(function(agent)
    kitty { 'focus-window', '--match', 'id:' .. agent.id }
  end)
end

--- Send arbitrary text (e.g. from other modules) to the agent and submit it.
function M.send_text(text, opts)
  with_agent(function(agent)
    send(agent, text, opts)
  end)
end

return M
