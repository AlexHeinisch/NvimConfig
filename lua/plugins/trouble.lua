require('trouble').setup {}

vim.keymap.set('n', '<leader>q', function()
  require('trouble').toggle { mode = 'diagnostics', filter = { buf = 0 } }
end, { desc = 'Diagnostics of this buffer ([Q]uickfix, Trouble)' })
vim.keymap.set('n', '<leader>xx', function()
  require('trouble').toggle { mode = 'diagnostics' }
end, { desc = 'Trouble: Workspace Diagnostics' })
vim.keymap.set('n', '<leader>xt', function()
  require('trouble').toggle { mode = 'todo' }
end, { desc = 'Trouble: TODOs' })
vim.keymap.set('n', '<leader>xr', function()
  require('trouble').toggle { mode = 'lsp_references' }
end, { desc = 'Trouble: LSP References' })
