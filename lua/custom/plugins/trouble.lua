-- To activate: add `require 'custom.plugins.trouble'` to the plugin list in init.lua
return {
  'folke/trouble.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  keys = {
    { '<leader>xx', function() require('trouble').toggle({ mode = 'diagnostics' }) end,                        desc = 'Trouble: Workspace Diagnostics' },
    { '<leader>xd', function() require('trouble').toggle({ mode = 'diagnostics', filter = { buf = 0 } }) end, desc = 'Trouble: Document Diagnostics' },
    { '<leader>xt', function() require('trouble').toggle({ mode = 'todo' }) end,                               desc = 'Trouble: TODOs' },
    { '<leader>xr', function() require('trouble').toggle({ mode = 'lsp_references' }) end,                    desc = 'Trouble: LSP References' },
  },
  opts = {},
}
