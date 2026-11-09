-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true

-- Track keymap usage (:KeymapReport). Must run before any keymap or plugin is defined.
require('custom.utils.keymap-stats').setup()

-- Java/Kotlin language server: 'intellij' (headless intellij-server, needs Ultimate) or 'jdtls'
vim.g.java_lsp = 'intellij'

-- [[ Setting options ]]
-- See `:help vim.o`
-- NOTE: You can change these options as you wish!
--  For more options, you can see `:help option-list`

-- Make line numbers default
vim.o.number = true
-- You can also add relative line numbers, to help with jumping.
--  Experiment for yourself to see if you like it!
vim.o.relativenumber = true

-- Enable mouse mode, can be useful for resizing splits for example!
vim.o.mouse = 'a'

-- Don't show the mode, since it's already in the status line
vim.o.showmode = false

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'
end)

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.o.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250

-- Decrease mapped sequence wait time
vim.o.timeoutlen = 300

-- Configure how new splits should be opened
vim.o.splitright = true
vim.o.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
--
--  Notice listchars is set using `vim.opt` instead of `vim.o`.
--  It is very similar to `vim.o` but offers an interface for conveniently interacting with tables.
--   See `:help lua-options`
--   and `:help lua-options-guide`
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type!
vim.o.inccommand = 'split'

-- Default border for floating windows (LSP hover, signature help, diagnostics, ...)
vim.o.winborder = 'rounded'

-- Show which line your cursor is on
vim.o.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.o.scrolloff = 10

-- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
-- instead raise a dialog asking if you wish to save the current file(s)
-- See `:help 'confirm'`
vim.o.confirm = true

-- Default tab settings
vim.o.tabstop = 4      -- Number of spaces a tab counts for
vim.o.shiftwidth = 4   -- Number of spaces for auto-indent
vim.o.softtabstop = 4  -- Number of spaces for <Tab> in insert mode
vim.o.expandtab = true -- Convert tabs to spaces

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- TIP: Disable arrow keys in normal mode
vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Window navigation (<C-hjkl>, also across kitty windows) and resizing (<A-hjkl>)
-- live in lua/custom/plugins/smart-splits.lua.

-- Send file / selection references to the coding agent in another kitty window (<leader>a...)
require('custom.utils.kitty-agent').setup()

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- Reload buffers that were changed on disk (e.g. by a coding agent). 'autoread' alone
-- only reloads when Neovim happens to check, so trigger the check explicitly.
vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'CursorHold', 'CursorHoldI', 'TermLeave' }, {
  desc = 'Reload files changed outside of Neovim',
  group = vim.api.nvim_create_augroup('custom-autoread', { clear = true }),
  callback = function()
    if vim.fn.mode() ~= 'c' and vim.fn.getcmdwintype() == '' then
      vim.cmd 'checktime'
    end
  end,
})
vim.api.nvim_create_autocmd('FileChangedShellPost', {
  desc = 'Notify when a file was reloaded from disk',
  group = 'custom-autoread',
  callback = function(args)
    vim.notify('Reloaded ' .. vim.fn.fnamemodify(args.file, ':.') .. ' (changed on disk)', vim.log.levels.INFO)
  end,
})

-- [[ Custom commands ]]
local json_utils = require 'custom.utils.json'
vim.api.nvim_create_user_command('FormatJson', function(opts)
  json_utils.format_json(opts.line1, opts.line2)
end, { range = true, desc = 'Format JSON, expanding nested JSON strings' })

-- [[ Install `lazy.nvim` plugin manager ]]
--    See `:help lazy.nvim.txt` or https://github.com/folke/lazy.nvim for more info
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then
    error('Error cloning lazy.nvim:\n' .. out)
  end
end

---@type vim.Option
local rtp = vim.opt.rtp
rtp:prepend(lazypath)

-- [[ Configure and install plugins ]]
--
--  To check the current status of your plugins, run
--    :Lazy
--
--  You can press `?` in this menu for help. Use `:q` to close the window
--
--  To update plugins you can run
--    :Lazy update
--
-- NOTE: Here is where you install your plugins.
require('lazy').setup({

  'NMAC427/guess-indent.nvim', -- Detect tabstop and shiftwidth automatically

  -- Git
  require 'custom.plugins.gitsigns',
  require 'custom.plugins.neogit',
  require 'custom.plugins.diffview',

  -- Key Helper bar on bottom
  require 'custom.plugins.which-key',

  -- Telescope
  require 'custom.plugins.telescope',

  -- LSP Plugins
  require 'custom.plugins.lazydev',
  require 'custom.plugins.nvim-jdtls',
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
  require 'kickstart.plugins.debug',

  -- Diagnostics panel
  require 'custom.plugins.trouble',

  -- Navigation
  require 'kickstart.plugins.neo-tree',
  require 'custom.plugins.smart-splits',

  -- Habits: hints for inefficient motions (`:Hardtime report`)
  require 'custom.plugins.hardtime',
}, {
  ui = {
    -- If you are using a Nerd Font: set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
