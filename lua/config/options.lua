-- [[ Options ]] See `:help vim.o` and `:help option-list`.

vim.o.number = true
vim.o.relativenumber = true
vim.o.mouse = 'a'
vim.o.showmode = false -- the status line shows the mode

-- Sync clipboard between OS and Neovim. Scheduled after `UiEnter` because it can increase startup time.
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'
end)

vim.o.breakindent = true
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true

vim.o.signcolumn = 'yes'
vim.o.updatetime = 250
vim.o.timeoutlen = 300 -- mapped sequence wait time

vim.o.splitright = true
vim.o.splitbelow = true

-- Show certain whitespace characters (`:help 'list'`, `:help 'listchars'`)
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

vim.o.inccommand = 'split' -- preview substitutions live
vim.o.winborder = 'rounded' -- border for floating windows (hover, signature help, diagnostics, ...)
vim.o.cursorline = true
vim.o.scrolloff = 10

-- Ask whether to save instead of failing on `:q` with unsaved changes
vim.o.confirm = true

-- Default tab settings (guess-indent overrides per file)
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.softtabstop = 4
vim.o.expandtab = true

-- Autosave (see config/autocmds.lua) relies on this.
vim.o.autowriteall = true
