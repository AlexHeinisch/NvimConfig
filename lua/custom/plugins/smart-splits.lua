-- Seamless <C-hjkl> navigation (and <A-hjkl> resizing) across Neovim splits and kitty windows.
-- Requires the matching block in ~/.config/kitty/kitty.conf (see "smart-splits" there).
-- Not lazy: the kitty backend sets the IS_NVIM user var at startup, which kitty uses
-- to decide whether to pass <C-hjkl> through to Neovim.
return {
  'smart-splits-nvim/smart-splits.nvim',
  version = '^3.0.0',
  lazy = false,
  dependencies = {
    {
      'smart-splits-nvim/backend-kitty',
      main = 'smart-splits-backend-kitty',
      build = './kitten/install_relative_resize.lua', -- copies relative_resize.py to ~/.config/kitty
      opts = {},
    },
  },
  opts = {
    mux = { backend = 'smart-splits-backend-kitty' },
  },
  keys = {
    { '<C-h>', function() require('smart-splits').move_cursor_left() end, desc = 'Move to left window/pane' },
    { '<C-j>', function() require('smart-splits').move_cursor_down() end, desc = 'Move to lower window/pane' },
    { '<C-k>', function() require('smart-splits').move_cursor_up() end, desc = 'Move to upper window/pane' },
    { '<C-l>', function() require('smart-splits').move_cursor_right() end, desc = 'Move to right window/pane' },
    { '<A-h>', function() require('smart-splits').resize_left() end, desc = 'Resize left' },
    { '<A-j>', function() require('smart-splits').resize_down() end, desc = 'Resize down' },
    { '<A-k>', function() require('smart-splits').resize_up() end, desc = 'Resize up' },
    { '<A-l>', function() require('smart-splits').resize_right() end, desc = 'Resize right' },
  },
}
