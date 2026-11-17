-- [[ Autocommands and custom commands ]]

vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- Save modified buffers when focus leaves Neovim or the buffer, so other tools (the Java language
-- server, build tools) always see the file as it is in the editor. Unnamed, read-only and
-- special buffers are skipped. FocusLost needs focus events from the terminal (kitty sends them).
vim.api.nvim_create_autocmd({ 'FocusLost', 'BufLeave' }, {
  desc = 'Autosave modified buffers',
  group = vim.api.nvim_create_augroup('custom-autosave', { clear = true }),
  callback = function(event)
    if event.event == 'FocusLost' then
      vim.cmd 'silent! wall'
    elseif vim.bo.modified and vim.bo.buftype == '' and vim.api.nvim_buf_get_name(0) ~= '' then
      vim.cmd 'silent! update'
    end
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

local json_utils = require 'custom.utils.json'
vim.api.nvim_create_user_command('FormatJson', function(opts)
  json_utils.format_json(opts.line1, opts.line2)
end, { range = true, desc = 'Format JSON, expanding nested JSON strings' })
