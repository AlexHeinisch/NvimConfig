-- [[ lazy.nvim bootstrap and plugin list ]]  (`:Lazy` shows status, `:Lazy update` updates)
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', 'https://github.com/folke/lazy.nvim.git', lazypath }
  if vim.v.shell_error ~= 0 then
    error('Error cloning lazy.nvim:\n' .. out)
  end
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup({

  'NMAC427/guess-indent.nvim', -- Detect tabstop and shiftwidth automatically

  -- Git
  require 'custom.plugins.gitsigns',
  require 'custom.plugins.neogit',
  require 'custom.plugins.diffview',

  -- Key helper bar on bottom
  require 'custom.plugins.which-key',

  -- Telescope
  require 'custom.plugins.telescope',

  -- LSP
  require 'custom.plugins.lazydev',
  require 'custom.plugins.intellij-lsp',
  require 'custom.plugins.nvim-lspconfig',
  require 'custom.plugins.conform',
  require 'custom.plugins.blink',

  -- Theme
  require 'custom.plugins.tokyonight',
  -- require 'custom.plugins.catppuccin',

  -- QOL
  require 'custom.plugins.todo-comments',
  require 'custom.plugins.mini',

  -- Treesitter
  require 'custom.plugins.nvim-treesitter',
  require 'custom.plugins.treesitter-textobjects',
  require 'custom.plugins.treesitter-context',

  -- Debugging
  require 'custom.plugins.debug',

  -- Diagnostics panel
  require 'custom.plugins.trouble',

  -- Navigation
  require 'custom.plugins.neo-tree',
  require 'custom.plugins.smart-splits',
  require 'custom.plugins.harpoon',

  -- Habits: hints for inefficient motions (`:Hardtime report`)
  require 'custom.plugins.hardtime',
}, {
  change_detection = { notify = false },
  performance = {
    rtp = {
      disabled_plugins = { 'gzip', 'tarPlugin', 'tohtml', 'tutor', 'zipPlugin' },
    },
  },
})
