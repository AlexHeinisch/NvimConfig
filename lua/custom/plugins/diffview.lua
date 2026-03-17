return {
  'sindrets/diffview.nvim',
  cmd = { 'DiffviewOpen', 'DiffviewClose', 'DiffviewToggleFiles', 'DiffviewFocusFiles', 'DiffviewFileHistory' },
  keys = {
    {
      '<leader>vd',
      function()
        local view = require('diffview.lib').get_current_view()
        if view then
          vim.cmd 'DiffviewClose'
        else
          vim.cmd 'DiffviewOpen'
        end
      end,
      desc = '[D]iffview toggle',
    },
    { '<leader>vh', '<cmd>DiffviewFileHistory %<cr>', desc = 'File [h]istory (current file)' },
    { '<leader>vH', '<cmd>DiffviewFileHistory<cr>', desc = 'File [H]istory (all)' },
    { '<leader>vm', '<cmd>DiffviewOpen develop<cr>', desc = 'Diff against develop' },
  },
  config = function()
    require('diffview').setup {
      enhanced_diff_hl = true, -- Better syntax highlighting in diffs
      view = {
        merge_tool = {
          layout = 'diff3_mixed',
        },
      },
    }
  end,
}
