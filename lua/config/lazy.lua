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

  -- One spec per plugin in lua/plugins/ (loaded alphabetically; load order is decided by lazy.nvim).
  { import = 'plugins' },
}, {
  change_detection = { notify = false },
  performance = {
    rtp = {
      disabled_plugins = { 'gzip', 'netrwPlugin', 'tarPlugin', 'tohtml', 'tutor', 'zipPlugin' },
    },
  },
})
