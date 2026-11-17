-- Pins the enclosing class / method signature at the top of the window.
require('treesitter-context').setup {
  max_lines = 3, -- class + method + one nested block is plenty
  multiline_threshold = 1, -- show only the first line of multi-line signatures
  trim_scope = 'outer',
}

vim.keymap.set('n', '[C', function()
  require('treesitter-context').go_to_context(vim.v.count1)
end, { desc = 'Jump to [C]ontext (treesitter)' })
vim.keymap.set('n', '<leader>tc', '<cmd>TSContext toggle<cr>', { desc = '[T]oggle Treesitter [C]ontext' })
