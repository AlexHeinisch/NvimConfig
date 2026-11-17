return { -- Collection of various small independent plugins/modules
  'echasnovski/mini.nvim',
  config = function()
    -- Simple and easy statusline.
    --  You could remove this setup call if you don't like it,
    --  and try some other statusline plugin
    local statusline = require 'mini.statusline'
    statusline.setup { use_icons = true }

    -- Custom location format, plus LSP client names and the harpoon slot of the current file.
    ---@diagnostic disable-next-line: duplicate-set-field
    statusline.section_location = function()
      return '%2l:%-2v'
    end

    local function lsp_clients()
      local names = {}
      for _, c in ipairs(vim.lsp.get_clients { bufnr = 0 }) do
        table.insert(names, c.name)
      end
      return #names > 0 and (' ' .. table.concat(names, ',')) or ''
    end

    local function harpoon_slot()
      local ok, harpoon = pcall(require, 'harpoon')
      if not ok then
        return ''
      end
      local list = harpoon:list()
      local item = list:get_by_value(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':.'))
      if not item then
        return ''
      end
      for i = 1, list:length() do
        if list:get(i) == item then
          return string.format('󰛢 %d/%d', i, list:length())
        end
      end
      return ''
    end

    statusline.config.content.active = function()
      local mode, mode_hl = statusline.section_mode { trunc_width = 120 }
      local git = statusline.section_git { trunc_width = 40 }
      local diff = statusline.section_diff { trunc_width = 75 }
      local diagnostics = statusline.section_diagnostics { trunc_width = 75 }
      local filename = statusline.section_filename { trunc_width = 140 }
      local fileinfo = statusline.section_fileinfo { trunc_width = 120 }
      local search = statusline.section_searchcount { trunc_width = 75 }
      return statusline.combine_groups {
        { hl = mode_hl, strings = { mode } },
        { hl = 'MiniStatuslineDevinfo', strings = { git, diff, diagnostics } },
        '%<',
        { hl = 'MiniStatuslineFilename', strings = { filename } },
        '%=',
        { hl = 'MiniStatuslineFileinfo', strings = { harpoon_slot(), lsp_clients(), fileinfo } },
        { hl = mode_hl, strings = { search, statusline.section_location {} } },
      }
    end
    require('mini.indentscope').setup()
    require('mini.surround').setup()
    -- ... and there is more!
    --  Check out: https://github.com/echasnovski/mini.nvim
  end,
}
