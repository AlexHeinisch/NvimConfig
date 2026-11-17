-- Reorders the sections of intellij-lsp.nvim's debug panel (<leader>dv): Locals, Watches, then
-- Call stack (the plugin renders Call stack first and has no option for the order).
--
-- The plugin builds the whole panel in one function (`M._render` in lua/intellij-lsp/debug.lua), so
-- this loads a patched copy of that file in place of the original via package.preload, swapping the
-- three section blocks. If a plugin update changes the code so the anchors no longer match, the
-- original file is loaded untouched and a warning is shown. Call `apply()` before the plugin's
-- setup() requires the module. To remove: delete this file and its call in plugins/intellij-lsp.lua.
local M = {}

local MODULE = 'intellij-lsp.debug'

--- @param src string source of debug.lua
--- @return string|nil patched, or nil when the anchors were not found
function M.reorder(src)
  local BLANK = "  table.insert(lines, '')\n  table.insert(rows, { kind = 'blank' })\n"
  local stack_at = src:find("  header('Call stack')\n", 1, true)
  local locals_at = src:find(BLANK .. "  header('Locals')\n", 1, true)
  local watches_at = src:find(BLANK .. "  header('Watches')\n", 1, true)
  local end_at = src:find('\n  panel.rows = rows\n', 1, true)
  if not (stack_at and locals_at and watches_at and end_at) or not (stack_at < locals_at and locals_at < watches_at and watches_at < end_at) then
    return nil
  end
  local stack = src:sub(stack_at, locals_at - 1)
  local locals = src:sub(locals_at + #BLANK, watches_at - 1) -- without its leading blank line
  local watches = src:sub(watches_at, end_at) -- with its leading blank line
  -- `current_frame_line` is declared inside the stack block, so the new order keeps it in scope
  -- for the extmark code after it.
  return src:sub(1, stack_at - 1) .. locals .. watches .. BLANK .. stack .. src:sub(end_at + 1)
end

function M.apply()
  local path = vim.api.nvim_get_runtime_file('lua/intellij-lsp/debug.lua', false)[1]
  if not path then
    return
  end
  local src = table.concat(vim.fn.readfile(path), '\n') .. '\n'
  local patched = M.reorder(src)
  if not patched then
    vim.notify('intellij-debug-layout: debug panel code changed, keeping the default section order', vim.log.levels.WARN)
    return
  end
  package.preload[MODULE] = function(name)
    local chunk, err = load(patched, '@' .. path)
    if not chunk then
      error(err)
    end
    return chunk(name, path)
  end
end

return M
