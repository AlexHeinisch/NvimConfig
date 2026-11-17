return { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    event = 'VimEnter', -- Sets the loading event to 'VimEnter'
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
        -- set icon mappings to true if you have a Nerd Font
        mappings = vim.g.have_nerd_font,
        -- If you are using a Bead Font: set icons.keys to an empty table which will use the
        -- default which-key.nvim defined Nerd Font icons, otherwise define a string table
        keys = vim.g.have_nerd_font and {} or {
          Up = '<Up> ',
          Down = '<Down> ',
          Left = '<Left> ',
          Right = '<Right> ',
          C = '<C-…> ',
          M = '<M-…> ',
          D = '<D-…> ',
          S = '<S-…> ',
          CR = '<CR> ',
          Esc = '<Esc> ',
          ScrollWheelDown = '<ScrollWheelDown> ',
          ScrollWheelUp = '<ScrollWheelUp> ',
          NL = '<NL> ',
          BS = '<BS> ',
          Space = '<Space> ',
          Tab = '<Tab> ',
          F1 = '<F1>',
          F2 = '<F2>',
          F3 = '<F3>',
          F4 = '<F4>',
          F5 = '<F5>',
          F6 = '<F6>',
          F7 = '<F7>',
          F8 = '<F8>',
          F9 = '<F9>',
          F10 = '<F10>',
          F11 = '<F11>',
          F12 = '<F12>',
        },
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
