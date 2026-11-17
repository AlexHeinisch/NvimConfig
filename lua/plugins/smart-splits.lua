-- Seamless <C-hjkl> navigation (and <A-hjkl> resizing) across Neovim splits and herdr panes.
-- The Neovim -> herdr direction is the backend in lua/util/smart_splits_herdr.lua.
-- The herdr -> Neovim direction is ~/.config/herdr/smart-nav.sh, bound in herdr's config.toml:
-- it forwards the key to Neovim when Neovim is the focused pane, otherwise moves herdr focus.
require('smart-splits').setup {
  mux = { backend = 'util.smart_splits_herdr' },
}

vim.keymap.set('n', '<C-h>', function()
  require('smart-splits').move_cursor_left()
end, { desc = 'Move to left window/pane' })
vim.keymap.set('n', '<C-j>', function()
  require('smart-splits').move_cursor_down()
end, { desc = 'Move to lower window/pane' })
vim.keymap.set('n', '<C-k>', function()
  require('smart-splits').move_cursor_up()
end, { desc = 'Move to upper window/pane' })
vim.keymap.set('n', '<C-l>', function()
  require('smart-splits').move_cursor_right()
end, { desc = 'Move to right window/pane' })
vim.keymap.set('n', '<A-h>', function()
  require('smart-splits').resize_left()
end, { desc = 'Resize left' })
vim.keymap.set('n', '<A-j>', function()
  require('smart-splits').resize_down()
end, { desc = 'Resize down' })
vim.keymap.set('n', '<A-k>', function()
  require('smart-splits').resize_up()
end, { desc = 'Resize up' })
vim.keymap.set('n', '<A-l>', function()
  require('smart-splits').resize_right()
end, { desc = 'Resize right' })
