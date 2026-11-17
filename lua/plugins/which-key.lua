-- Shows pending key bindings and registers the <leader> groups.
require('which-key').setup {
  -- delay between pressing a key and opening which-key (milliseconds)
  -- this setting is independent of vim.o.timeoutlen
  delay = 0,
  -- use to disable the view for operations
  -- defer = function(ctx)
  --  if vim.list_contains({ 'd', 'y' }, ctx.operator) then
  --    return true
  --  end
  --  return vim.list_contains({ '<C-V>', 'V' }, ctx.mode)
  -- end,
  icons = {
    mappings = true, -- Nerd Font icons
  },

  -- Document existing key chains
  spec = {
    { '<leader>s', group = '[S]earch' },
    { '<leader>l', group = '[L]anguage server control' },
    { '<leader>g', group = '[G]o to / code actions' },
    { '<leader>t', group = '[T]oggle' },
    { '<leader>h', group = 'Git [H]unk (gitsigns)', mode = { 'n', 'v' } },
    { '<leader>d', group = '[D]ebug and test' },
    { '<leader>x', group = 'Trouble ([X])' },

    -- Harpoon <leader>1..9: one line instead of nine
    { '<leader>1', desc = 'Harpoon: jump to file 1…9 (<leader>N)' },
    (function()
      local hidden = {}
      for i = 2, 9 do
        table.insert(hidden, { '<leader>' .. i, hidden = true })
      end
      return hidden
    end)(),
  },
}

-- Neovim only honours a buffer-local `nowait` mapping if it comes before longer partial matches in the
-- buffer's mapping list, and new mappings are inserted at the front. Maps added after which-key's trigger
-- (LSP attach, gitsigns, IntelliJ) therefore push `<Space>` behind `<leader>g…`/`<leader>h…`, and Neovim
-- waits the full 'timeoutlen' before the popup opens. Re-adding the triggers moves them back to the front.
local function refresh_triggers(buf)
  local Triggers = require 'which-key.triggers'
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  for id, trigger in pairs(vim.deepcopy(Triggers._triggers)) do
    if trigger.buf == buf then
      pcall(vim.keymap.del, trigger.mode, trigger.keys, { buffer = buf })
      Triggers._triggers[id] = nil
      Triggers.add(trigger)
    end
  end
end

-- Used by plugins that add buffer-local maps after the buffer was set up (gitsigns' on_attach).
_G.WhichKeyRefresh = function(buf)
  vim.schedule(function()
    refresh_triggers(buf)
  end)
end

vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('which-key-refresh', { clear = true }),
  desc = 'Keep which-key triggers ahead of buffer-local maps',
  callback = function(ev)
    -- later than the attach handlers (IntelliJ and the LSP maps register theirs on LspAttach too)
    vim.defer_fn(function()
      refresh_triggers(ev.buf)
    end, 50)
  end,
})
