return { -- Highlight, edit, and navigate code
  'nvim-treesitter/nvim-treesitter',
  -- The `main` branch is the rewrite that supports Neovim 0.12+.
  -- `master` is frozen and breaks on 0.12 (custom query directives get node lists).
  -- Requires the `tree-sitter` CLI (>= 0.26) to install parsers.
  branch = 'main',
  lazy = false, -- main branch does not support lazy-loading
  build = ':TSUpdate',
  config = function()
    local ts = require 'nvim-treesitter'

    -- Parsers to always have installed (async; no-op if already present).
    -- markdown/markdown_inline are installed here too so parser and queries
    -- come from the same source and stay in sync.
    ts.install {
      'bash',
      'c',
      'diff',
      'html',
      'lua',
      'luadoc',
      'markdown',
      'markdown_inline',
      'query',
      'vim',
      'vimdoc',
      'java',
    }

    -- Languages that still need vim regex highlighting / have bad TS indent.
    local regex_highlight = { ruby = true }
    local no_ts_indent = { ruby = true }

    local function attach(buf, lang)
      if not pcall(vim.treesitter.start, buf, lang) then
        return
      end
      if regex_highlight[lang] then
        vim.bo[buf].syntax = 'ON'
      end
      if not no_ts_indent[lang] then
        vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end
    end

    vim.api.nvim_create_autocmd('FileType', {
      group = vim.api.nvim_create_augroup('custom-treesitter', { clear = true }),
      callback = function(args)
        local buf = args.buf
        local lang = vim.treesitter.language.get_lang(args.match)
        if not lang then
          return
        end

        -- Parser already available (installed or bundled with Neovim)
        if vim.treesitter.language.add(lang) then
          attach(buf, lang)
          return
        end

        -- Auto-install missing parsers (replacement for `auto_install = true`)
        if vim.tbl_contains(ts.get_available(), lang) then
          ts.install({ lang }):await(function()
            vim.schedule(function()
              if vim.api.nvim_buf_is_valid(buf) then
                attach(buf, lang)
              end
            end)
          end)
        end
      end,
    })
  end,
  -- There are additional plugins built on nvim-treesitter (use their `main` branches):
  --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
  --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
  -- Incremental selection is built into Neovim 0.12 (`an`/`in` in visual mode, see `:h v_an`).
}
