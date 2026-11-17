-- [[ Basic keymaps ]] See `:help vim.keymap.set()`.
-- Window navigation (<C-hjkl>, also across herdr panes) and resizing (<A-hjkl>)
-- live in lua/custom/plugins/smart-splits.lua. Arrow-key discipline is handled by hardtime.nvim.

-- Clear search highlights on <Esc>
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Exit terminal mode (the default is <C-\><C-n>). May not work in every terminal/multiplexer.
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
