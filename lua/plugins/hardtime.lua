-- Hints about inefficient motions (e.g. `jjjj`, `x x x`). `:Hardtime report` lists the most frequent ones.
-- Complements lua/util/keymap-stats.lua (`:KeymapReport`).
return {
  'm4xshen/hardtime.nvim',
  event = 'VeryLazy',
  dependencies = { 'MunifTanjim/nui.nvim' },
  opts = {
    restriction_mode = 'hint', -- hint, don't block keys
    disable_mouse = false, -- mouse = 'a' is set on purpose
  },
}
