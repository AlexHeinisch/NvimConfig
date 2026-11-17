-- Hints about inefficient motions (e.g. `jjjj`, `x x x`). `:Hardtime report` lists the most frequent ones.
-- Complements lua/util/keymap-stats.lua (`:KeymapReport`).
require('hardtime').setup {
  restriction_mode = 'hint', -- hint, don't block keys
  disable_mouse = false, -- mouse = 'a' is set on purpose
}
