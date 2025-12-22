-- See `:help gitsigns` to understand what the configuration keys do
return { -- Adds git related signs to the gutter, as well as utilities for managing changes
  'lewis6991/gitsigns.nvim',
  opts = {
    signs = {
      add = { text = '+' },
      change = { text = '~' },
      delete = { text = '_' },
      topdelete = { text = '‾' },
      changedelete = { text = '~' },
    },
  },
  keys = {
    -- Toggle inline blame (virtual text at end of line)
    --{ '<leader>hb', '<cmd>Gitsigns toggle_current_line_blame<cr>', desc = 'Toggle Blame Line' },

    -- Or open full blame window (fugitive-style)
    --{ '<leader>hB', '<cmd>Gitsigns blame<cr>', desc = 'Blame Buffer' },
  }
}
