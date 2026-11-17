-- Shared by java.lua and kotlin.lua: pressing <CR> after a lone `/**` expands to a doc comment
-- skeleton with one tag line per thing the declaration below needs documented.
--
-- The open `/**` poisons the buffer's own treesitter parse (everything after it is "comment"), so
-- the lines below are cut at their first `{` or `;`, closed again, and parsed on their own by the
-- language module: `tags_for(src) -> string[]` returns lines like '@param a'.
local ls = require 'luasnip'
local s, t, i, d, sn = ls.snippet, ls.text_node, ls.insert_node, ls.dynamic_node, ls.snippet_node

local M = {}

--- Text of the declaration that starts on the line after `row` (0-based), cut at the first `{`/`;`.
function M.declaration_text(buf, row)
  local parts = {}
  for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, row + 1, row + 16, false)) do
    local stop = line:find '[{;]'
    if stop then
      table.insert(parts, line:sub(1, stop - 1))
      table.insert(parts, line:sub(stop, stop) == '{' and ' {}' or ';')
      break
    end
    table.insert(parts, line)
  end
  return table.concat(parts, '\n')
end

function M.node_text(node, src)
  return vim.treesitter.get_node_text(node, src)
end

--- @param tags_for fun(decl_text: string): string[]
local function make(tags_for)
  local function skeleton()
    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    local ok, list = pcall(function() return tags_for(M.declaration_text(0, row)) end)
    list = ok and list or {}

    -- ` * |`, a blank ` *` before the tags, then ` * @tag |` per tag
    local nodes = { t ' * ', i(1) }
    for n, tag in ipairs(list) do
      if n == 1 then
        table.insert(nodes, t { '', ' *' })
      end
      vim.list_extend(nodes, { t { '', ' * ' .. tag .. ' ' }, i(n + 1) })
    end
    table.insert(nodes, t { '', ' */' })
    return sn(nil, nodes)
  end

  return s('/**', { t { '/**', '' }, d(1, skeleton) })
end

M.make = make

local MODULES = { java = 'custom.snippets.java', kotlin = 'custom.snippets.kotlin' }

--- `<CR>` after a lone `/**`: replace it with the doc comment skeleton. Returns true when it
--- expanded, so a caller can fall through to the normal `<CR>` otherwise (see blink.lua).
function M.expand_on_enter()
  local module = MODULES[vim.bo.filetype]
  if not module then
    return false
  end
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  if col ~= #line or not line:match '^%s*/%*%*$' then
    return false
  end
  local start = line:find('/%*%*$') - 1
  ls.snip_expand(make(require(module).tags_for), {
    clear_region = { from = { row - 1, start }, to = { row - 1, col } },
  })
  return true
end

return M
