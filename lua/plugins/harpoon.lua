-- Pin a handful of files to numbered slots and jump to them directly.
-- Marks are stored per project (cwd) and per git branch, and survive restarts.
-- In the menu (<leader>M) the list is a normal buffer: reorder lines with dd/p, delete with dd, save with :w or close with q.
return {
  'ThePrimeagen/harpoon',
  branch = 'harpoon2',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    local harpoon = require 'harpoon'
    -- Shortened, icon-prefixed paths in the menu (util/path-display.lua); buffer text stays the real path.
    harpoon:extend {
      UI_CREATE = function(cx)
        require('util.path-display').attach_harpoon(cx.bufnr, cx.win_id)
      end,
    }
    -- harpoon calls `key()` on every `harpoon:list()`, and the statusline does that on every redraw,
    -- so the (cwd, branch) key is cached and only recomputed after something that can change it.
    local cached_key
    local function key()
      if not cached_key then
        local cwd = vim.uv.cwd() or ''
        local ok, res = pcall(function()
          return vim.system({ 'git', '-C', cwd, 'branch', '--show-current' }, { text = true }):wait()
        end)
        local branch = ok and res.code == 0 and vim.trim(res.stdout or '') or ''
        cached_key = branch ~= '' and (cwd .. '@' .. branch) or cwd
      end
      return cached_key
    end
    local group = vim.api.nvim_create_augroup('custom-harpoon-key', { clear = true })
    local function invalidate()
      cached_key = nil
    end
    vim.api.nvim_create_autocmd(
      { 'DirChanged', 'FocusGained', 'TermClose' },
      { group = group, callback = invalidate, desc = 'Harpoon key: cwd/branch may have changed' }
    )
    vim.api.nvim_create_autocmd('User', { group = group, pattern = 'Neogit*', callback = invalidate, desc = 'Harpoon key: Neogit changed the branch' })
    harpoon:setup {
      settings = {
        save_on_toggle = true, -- edits made in the menu are saved when it closes
        key = key,
      },
    }
  end,
  keys = function()
    local function list()
      return require('harpoon'):list()
    end
    local menu_opts = { ui_width_ratio = 0.8, ui_max_width = 120, title = ' Harpoon ', title_pos = 'center', border = 'rounded' }
    local keys = {
      {
        '<leader>m',
        function()
          list():add()
        end,
        desc = 'Harpoon: [M]ark file',
      },
      {
        '<leader>M',
        function()
          require('harpoon').ui:toggle_quick_menu(list(), menu_opts)
        end,
        desc = 'Harpoon: [M]enu',
      },
    }
    -- which-key shows these as a single "1…9" line (see which-key.lua spec)
    for i = 1, 9 do
      table.insert(keys, {
        '<leader>' .. i,
        function()
          list():select(i)
        end,
        desc = 'Harpoon: file ' .. i,
      })
    end
    return keys
  end,
}
