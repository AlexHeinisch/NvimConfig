-- Pin a handful of files to numbered slots and jump to them directly.
-- Marks are stored per project (cwd) and per git branch, and survive restarts.
-- In the menu (<leader>M) the list is a normal buffer: reorder lines with dd/p, delete with dd, save with :w or close with q.
return {
  'ThePrimeagen/harpoon',
  branch = 'harpoon2',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    local harpoon = require 'harpoon'
    -- Shortened, icon-prefixed paths in the menu (custom/utils/path-display.lua); buffer text stays the real path.
    harpoon:extend {
      UI_CREATE = function(cx)
        require('custom.utils.path-display').attach_harpoon(cx.bufnr, cx.win_id)
      end,
    }
    harpoon:setup {
      settings = {
        save_on_toggle = true, -- edits made in the menu are saved when it closes
        key = function()
          local cwd = vim.uv.cwd() or ''
          local branch = vim.trim(vim.fn.system { 'git', '-C', cwd, 'branch', '--show-current' })
          return vim.v.shell_error == 0 and branch ~= '' and (cwd .. '@' .. branch) or cwd
        end,
      },
    }
  end,
  keys = function()
    local function list()
      return require('harpoon'):list()
    end
    local menu_opts = { ui_width_ratio = 0.8, ui_max_width = 120, title = ' Harpoon ', title_pos = 'center', border = 'rounded' }
    local keys = {
      { '<leader>m', function() list():add() end, desc = 'Harpoon: [M]ark file' },
      { '<leader>M', function() require('harpoon').ui:toggle_quick_menu(list(), menu_opts) end, desc = 'Harpoon: [M]enu' },
    }
    -- which-key shows these as a single "1…9" line (see which-key.lua spec)
    for i = 1, 9 do
      table.insert(keys, { '<leader>' .. i, function() list():select(i) end, desc = 'Harpoon: file ' .. i })
    end
    return keys
  end,
}
