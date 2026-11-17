-- Treesitter text objects and motions (main branch, required for nvim-treesitter `main`).
--   af / if   method (incl. constructors)    ac / ic   class
--   aa / ia   parameter / argument           al / il   loop
--   ]m / [m   next / previous method start   ]M / [M   method end
--   ]] / [[   next / previous class start
-- (ai/ii are taken by mini.indentscope.)
return {
  'nvim-treesitter/nvim-treesitter-textobjects',
  branch = 'main',
  lazy = false,
  config = function()
    require('nvim-treesitter-textobjects').setup {
      select = {
        lookahead = true,
        selection_modes = {
          ['@function.outer'] = 'V',
          ['@class.outer'] = 'V',
        },
      },
      move = { set_jumps = true },
    }

    local select = function(capture)
      return function()
        require('nvim-treesitter-textobjects.select').select_textobject(capture, 'textobjects')
      end
    end
    local objects = {
      af = { '@function.outer', 'method' },
      ['if'] = { '@function.inner', 'inner method' },
      ac = { '@class.outer', 'class' },
      ic = { '@class.inner', 'inner class' },
      aa = { '@parameter.outer', 'parameter' },
      ia = { '@parameter.inner', 'inner parameter' },
      al = { '@loop.outer', 'loop' },
      il = { '@loop.inner', 'inner loop' },
    }
    for lhs, o in pairs(objects) do
      vim.keymap.set({ 'x', 'o' }, lhs, select(o[1]), { desc = 'TS: ' .. o[2] })
    end

    local move = function(fn, capture)
      return function()
        require('nvim-treesitter-textobjects.move')[fn](capture, 'textobjects')
      end
    end
    local motions = {
      [']m'] = { 'goto_next_start', '@function.outer', 'Next method start' },
      ['[m'] = { 'goto_previous_start', '@function.outer', 'Previous method start' },
      [']M'] = { 'goto_next_end', '@function.outer', 'Next method end' },
      ['[M'] = { 'goto_previous_end', '@function.outer', 'Previous method end' },
      [']]'] = { 'goto_next_start', '@class.outer', 'Next class start' },
      ['[['] = { 'goto_previous_start', '@class.outer', 'Previous class start' },
    }
    for lhs, m in pairs(motions) do
      vim.keymap.set({ 'n', 'x', 'o' }, lhs, move(m[1], m[2]), { desc = 'TS: ' .. m[3] })
    end
  end,
}
