-- Seamless <C-hjkl> navigation (and <A-hjkl> resizing) across Neovim splits and herdr panes.
-- The Neovim -> herdr direction is the backend in lua/custom/smart_splits_herdr.lua.
-- The herdr -> Neovim direction is ~/.config/herdr/smart-nav.sh, bound in herdr's config.toml:
-- it forwards the key to Neovim when Neovim is the focused pane, otherwise moves herdr focus.
return {
  'smart-splits-nvim/smart-splits.nvim',
  version = '^3.0.0',
  lazy = false,
  opts = {
    mux = { backend = 'custom.smart_splits_herdr' },
  },
  keys = {
    {
      '<C-h>',
      function()
        require('smart-splits').move_cursor_left()
      end,
      desc = 'Move to left window/pane',
    },
    {
      '<C-j>',
      function()
        require('smart-splits').move_cursor_down()
      end,
      desc = 'Move to lower window/pane',
    },
    {
      '<C-k>',
      function()
        require('smart-splits').move_cursor_up()
      end,
      desc = 'Move to upper window/pane',
    },
    {
      '<C-l>',
      function()
        require('smart-splits').move_cursor_right()
      end,
      desc = 'Move to right window/pane',
    },
    {
      '<A-h>',
      function()
        require('smart-splits').resize_left()
      end,
      desc = 'Resize left',
    },
    {
      '<A-j>',
      function()
        require('smart-splits').resize_down()
      end,
      desc = 'Resize down',
    },
    {
      '<A-k>',
      function()
        require('smart-splits').resize_up()
      end,
      desc = 'Resize up',
    },
    {
      '<A-l>',
      function()
        require('smart-splits').resize_right()
      end,
      desc = 'Resize right',
    },
  },
}
