return {
  'TimUntersberger/neogit',
  cmd = 'Neogit',
  keys = {
    { '<leader>vv', '<cmd>Neogit<cr>', desc = 'Neo[g]it' },
    { '<leader>vc', '<cmd>Neogit commit<cr>', desc = 'Neogit [c]ommit' },
    { '<leader>vp', '<cmd>Neogit pull<cr>', desc = 'Neogit [p]ull' },
    { '<leader>vP', '<cmd>Neogit push<cr>', desc = 'Neogit [P]ush' },
    { '<leader>vB', '<cmd>Telescope git_branches<cr>', desc = 'Telescope [B]ranches' },
  },
  config = function()
    require('neogit').setup {
      kind = 'split', -- opens neogit in a split
      signs = {
        -- { CLOSED, OPENED }
        section = { '', '' },
        item = { '', '' },
        hunk = { '', '' },
      },
      integrations = { diffview = true }, -- adds integration with diffview.nvim
    }
  end,
}
