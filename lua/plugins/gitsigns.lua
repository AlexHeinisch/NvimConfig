require('gitsigns').setup {
  signs = {
    add = { text = '│' },
    change = { text = '│' },
    delete = { text = '_' },
    topdelete = { text = '‾' },
    changedelete = { text = '~' },
    untracked = { text = '┆' },
  },
  -- Staged hunks use thicker/filled variants for clear visual distinction
  signs_staged_enable = true,
  signs_staged = {
    add = { text = '┃' },
    change = { text = '┃' },
    delete = { text = '▁' },
    topdelete = { text = '▔' },
    changedelete = { text = '▒' },
    untracked = { text = '┇' },
  },
  on_attach = function(bufnr)
    local gs = package.loaded.gitsigns
    local function map(mode, l, r, opts)
      opts = opts or {}
      opts.buffer = bufnr
      vim.keymap.set(mode, l, r, opts)
    end

    -- Hunk navigation (respects diff mode)
    map('n', ']h', function()
      if vim.wo.diff then
        vim.cmd.normal { ']c', bang = true }
      else
        gs.nav_hunk 'next'
      end
    end, { desc = 'Next [H]unk' })
    map('n', '[h', function()
      if vim.wo.diff then
        vim.cmd.normal { '[c', bang = true }
      else
        gs.nav_hunk 'prev'
      end
    end, { desc = 'Prev [H]unk' })

    -- Stage / unstage
    map('n', '<leader>hs', gs.stage_hunk, { desc = '[S]tage hunk' })
    map('n', '<leader>hu', gs.undo_stage_hunk, { desc = '[U]ndo stage hunk (session only)' })
    map('n', '<leader>hS', gs.stage_buffer, { desc = '[S]tage buffer' })
    map('n', '<leader>hU', gs.reset_buffer_index, { desc = '[U]nstage buffer' })
    -- Visual-mode staging: only stage selected lines
    map('v', '<leader>hs', function()
      gs.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
    end, { desc = '[S]tage hunk (selection)' })

    -- Reset
    map('n', '<leader>hr', gs.reset_hunk, { desc = '[R]eset hunk' })
    map('v', '<leader>hr', function()
      gs.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
    end, { desc = '[R]eset hunk (selection)' })
    map('n', '<leader>hR', gs.reset_buffer, { desc = '[R]eset buffer' })

    -- Inspect
    map('n', '<leader>hp', gs.preview_hunk, { desc = '[P]review hunk' })

    -- keep which-key's <Space> trigger in front of the maps added above (see plugins/which-key.lua)
    _G.WhichKeyRefresh(bufnr)
  end,
}
