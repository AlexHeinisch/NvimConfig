-- Shortened path display shared by Telescope and the Harpoon menu:
--   iam-service/src/main/java/com/acme/iam/user/UserService.java
--   -> iam-service/com/acme/…/UserService.java
-- * `src/{main,test}/{java,kotlin}/` is dropped.
-- * If the rest is still too wide, the leading dirs that fit are kept, then `…/`, then the file name.
-- * Directories are dimmed, the file name keeps normal highlighting.
local M = {}

M.dir_hl = 'TelescopeResultsComment'

local width = vim.fn.strdisplaywidth
local ELLIPSIS = '…'
local SOURCE_ROOT = { src = { main = true, test = true }, lang = { java = true, kotlin = true } }

--- Split `path` into components with their byte offsets (0-based, end-exclusive, without the slash).
local function components(path)
  local out, pos = {}, 0
  for part in (path .. '/'):gmatch '([^/]*)/' do
    table.insert(out, { text = part, s = pos, e = pos + #part })
    pos = pos + #part + 1
  end
  return out
end

--- Decide what to show for each component of `path` when `max` display cells are available.
--- Returns the directory components (each with `.mode` = 'keep' | 'strip' | 'elide') and the file component.
function M.plan(path, max)
  local parts = components(path)
  local file = table.remove(parts)
  for i = 1, #parts - 2 do
    if parts[i].text == 'src' and SOURCE_ROOT.src[parts[i + 1].text] and SOURCE_ROOT.lang[parts[i + 2].text] then
      for j = i, i + 2 do
        parts[j].mode = 'strip'
      end
      break
    end
  end

  local visible, used = {}, width(file.text)
  for _, p in ipairs(parts) do
    if p.mode ~= 'strip' then
      p.mode = 'keep'
      table.insert(visible, p)
      used = used + width(p.text) + 1
    end
  end

  if used > max then
    -- Keep the leading dirs that fit next to `…/` + file name; elide the rest.
    local budget = max - width(file.text) - width(ELLIPSIS .. '/')
    local kept = 0
    for _, p in ipairs(visible) do
      local w = width(p.text) + 1
      if kept + w > budget then
        break
      end
      kept = kept + w
      p.keep_fits = true
    end
    for _, p in ipairs(visible) do
      if not p.keep_fits then
        p.mode = 'elide'
      end
      p.keep_fits = nil
    end
  end
  return parts, file
end

--- Group consecutive hidden components into byte ranges of the original path.
--- Each range is { s, e, conceal } where `conceal` is '' (remove) or '…' (stands in for the dirs).
function M.hidden_ranges(parts)
  local ranges, cur = {}, nil
  for _, p in ipairs(parts) do
    if p.mode == 'keep' then
      cur = nil
    else
      if not cur then
        cur = { s = p.s, e = p.e + 1, elide = false }
        table.insert(ranges, cur)
      end
      cur.e = p.e + 1 -- include the slash
      cur.elide = cur.elide or p.mode == 'elide'
    end
  end
  return vim.tbl_map(function(r)
    -- An elided range keeps its last slash visible so it reads `…/`.
    return r.elide and { r.s, r.e - 1, ELLIPSIS } or { r.s, r.e, '' }
  end, ranges)
end

--- Shortened string plus the byte length of its directory part.
function M.shorten(path, max)
  local parts, file = M.plan(path, max)
  local out, prev_hidden = {}, false
  for _, p in ipairs(parts) do
    if p.mode == 'keep' then
      table.insert(out, p.text .. '/')
      prev_hidden = false
    elseif p.mode == 'elide' and not prev_hidden then
      table.insert(out, ELLIPSIS .. '/')
      prev_hidden = true
    end
  end
  local dirs = table.concat(out)
  local text = dirs .. file.text
  if width(text) > max then
    text = require('plenary.strings').truncate(text, max, nil, -1)
    return text, 0
  end
  return text, #dirs
end

-- [[ Telescope ]]

--- Width of the results list in the open picker, minus caret, icon and entry prefix.
--- (Entries are formatted while the results buffer, not the prompt, is current, so
--- telescope.state's per-prompt status can't be used here; find the results window instead.)
local function telescope_width(opts)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == 'TelescopeResults' then
      local caret = width(opts.selection_caret or '> ')
      local icon = 2 -- devicon + space
      return vim.api.nvim_win_get_width(win) - caret - icon - (opts.__prefix or 0) - 1
    end
  end
  return math.huge
end

--- Use as `defaults.path_display` in telescope.setup().
function M.telescope(opts, path)
  local cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.uv.cwd()
  local rel = require('plenary.path'):new(path):make_relative(cwd)
  local text, dir_len = M.shorten(rel, telescope_width(opts))
  local style = dir_len > 0 and { { { 0, dir_len }, M.dir_hl } } or {}
  return text, style
end

-- [[ Harpoon menu ]]
-- The menu buffer's text is what Harpoon saves, so it stays untouched: the shortened view is
-- drawn with extmarks (conceal, highlight, inline icon) and redrawn on every change.

local ns = vim.api.nvim_create_namespace 'custom-path-display'

local function render(buf, win)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_win_is_valid(win) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local info = vim.fn.getwininfo(win)[1]
  local avail = vim.api.nvim_win_get_width(win) - (info and info.textoff or 4) - 3 -- icon + space + margin
  local ok_icons, devicons = pcall(require, 'nvim-web-devicons')
  for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local row = i - 1
    if line ~= '' then
      if ok_icons then
        local icon, icon_hl = devicons.get_icon(vim.fn.fnamemodify(line, ':t'), nil, { default = true })
        vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
          virt_text = { { icon .. ' ', icon_hl } },
          virt_text_pos = 'inline',
          right_gravity = false,
        })
      end
      local parts, file = M.plan(line, avail)
      for _, r in ipairs(M.hidden_ranges(parts)) do
        vim.api.nvim_buf_set_extmark(buf, ns, row, r[1], { end_col = r[2], conceal = r[3] })
      end
      if file.s > 0 then
        vim.api.nvim_buf_set_extmark(buf, ns, row, 0, { end_col = file.s, hl_group = M.dir_hl })
      end
    end
  end
end

--- Attach the shortened view to a Harpoon menu (call from the UI_CREATE extension).
function M.attach_harpoon(buf, win)
  vim.wo[win].wrap = false
  vim.wo[win].conceallevel = 2
  vim.wo[win].concealcursor = 'n' -- full path only while editing the line in insert mode
  render(buf, win)
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'InsertLeave' }, {
    buffer = buf,
    callback = function()
      render(buf, win)
    end,
  })
end

return M
