-- Neo-tree: file system browser (also opens for `nvim <dir>`, replacing netrw).
-- https://github.com/nvim-neo-tree/neo-tree.nvim
require('neo-tree').setup {
  filesystem = {
    window = {
      mappings = {
        ['\\'] = 'close_window',
      },
    },
  },
}

vim.keymap.set('n', '\\', ':Neotree reveal<CR>', { desc = 'NeoTree reveal', silent = true })
