return { -- Useful plugin to show you pending keybinds.
  'folke/which-key.nvim',
  event = 'VeryLazy',
  opts = {
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
      { '<leader>v', group = '[V]ersion control (neogit, diffview)' },
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
  },
}
