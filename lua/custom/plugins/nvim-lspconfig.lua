-- Main LSP configuration. Java/Kotlin are served by intellij-lsp.nvim (see intellij-lsp.lua);
-- everything else goes through Mason + vim.lsp.config below.
return {
  'neovim/nvim-lspconfig',
  dependencies = {
    -- Mason must be loaded before its dependents so we need to set it up here.
    { 'mason-org/mason.nvim', opts = {} },
    'mason-org/mason-lspconfig.nvim',
    'WhoIsSethDaniel/mason-tool-installer.nvim',

    -- Useful status updates for LSP.
    {
      'j-hui/fidget.nvim',
      event = 'LspAttach',
      opts = {
        notification = {
          window = {
            normal_hl = 'Normal', -- Use Normal highlight group (respects transparent background)
            winblend = 0, -- No blending, fully transparent background
          },
        },
      },
      config = function(_, opts)
        require('fidget').setup(opts)
        -- Override fidget highlights to use transparent background
        vim.api.nvim_set_hl(0, 'FidgetTitle', { link = 'Normal' })
        vim.api.nvim_set_hl(0, 'FidgetTask', { link = 'Normal' })
      end,
    },

    -- Registers completion capabilities for every server (vim.lsp.config('*', ...)).
    'saghen/blink.cmp',
  },
  config = function()
    -- Runs when an LSP client attaches to a buffer: buffer-local maps and reference highlighting.
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('custom-lsp-attach', { clear = true }),
      callback = function(event)
        local map = function(keys, func, desc, mode)
          vim.keymap.set(mode or 'n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
        end
        local builtin = require 'telescope.builtin'

        map('<leader>gr', vim.lsp.buf.rename, '[R]e[n]ame')
        map('<leader>ga', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })
        map('<leader>gu', builtin.lsp_references, '[G]oto [R]eferences')
        map('<leader>gi', builtin.lsp_implementations, '[G]oto [I]mplementation')
        map('<leader>gd', builtin.lsp_definitions, '[G]oto [D]efinition') -- jump back with <C-t>
        map('<leader>gO', builtin.lsp_document_symbols, 'Open Document Symbols')
        map('<leader>gW', builtin.lsp_dynamic_workspace_symbols, 'Open Workspace Symbols')
        map('<leader>gt', builtin.lsp_type_definitions, '[G]oto [T]ype Definition')

        -- Hover / signature help with a size limit (border comes from 'winborder').
        local float_opts = { max_width = 80, max_height = 20 }
        map('K', function()
          vim.lsp.buf.hover(float_opts)
        end, 'Hover documentation')
        map('<C-s>', function()
          vim.lsp.buf.signature_help(float_opts)
        end, 'Signature help', { 'i', 's' })

        -- Highlight references of the word under the cursor while it rests there (`:help CursorHold`).
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client and client:supports_method('textDocument/documentHighlight', event.buf) then
          local group = vim.api.nvim_create_augroup('custom-lsp-highlight-' .. event.buf, { clear = true })
          vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
            buffer = event.buf,
            group = group,
            callback = vim.lsp.buf.document_highlight,
          })
          vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
            buffer = event.buf,
            group = group,
            callback = vim.lsp.buf.clear_references,
          })
        end

        if client and client:supports_method('textDocument/inlayHint', event.buf) then
          map('<leader>th', function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
          end, '[T]oggle Inlay [H]ints')
        end
      end,
    })

    -- Clean up the per-buffer highlight group once. The group is per buffer, so attaching a second
    -- client or buffer never wipes another buffer's autocmds.
    vim.api.nvim_create_autocmd('LspDetach', {
      group = vim.api.nvim_create_augroup('custom-lsp-detach', { clear = true }),
      callback = function(event)
        if #vim.lsp.get_clients { bufnr = event.buf } > 1 then
          return -- other clients still attached; keep the highlight autocmds
        end
        vim.lsp.buf.clear_references()
        pcall(vim.api.nvim_del_augroup_by_name, 'custom-lsp-highlight-' .. event.buf)
      end,
    })

    -- See :help vim.diagnostic.Opts
    vim.diagnostic.config {
      severity_sort = true,
      float = { source = 'if_many' },
      underline = { severity = vim.diagnostic.severity.ERROR },
      signs = vim.g.have_nerd_font and {
        text = {
          [vim.diagnostic.severity.ERROR] = '󰅚 ',
          [vim.diagnostic.severity.WARN] = '󰀪 ',
          [vim.diagnostic.severity.INFO] = '󰋽 ',
          [vim.diagnostic.severity.HINT] = '󰌶 ',
        },
      } or {},
      virtual_text = { source = 'if_many', spacing = 2 },
    }

    -- Servers to install and enable; values are passed to `vim.lsp.config(name, cfg)`.
    -- Java/Kotlin are served by intellij-lsp.nvim, so jdtls / kotlin-language-server are not listed.
    local servers = {
      lua_ls = {},
      angularls = {},
      docker_language_server = {}, -- Dockerfile and compose
      fish_lsp = {},
      helm_ls = {},
      htmx = {},
      lemminx = {}, -- XML
      ts_ls = {},
    }

    -- Ensure the servers and tools above are installed (`:Mason` shows the state).
    local ensure_installed = vim.tbl_keys(servers)
    vim.list_extend(ensure_installed, {
      'stylua', -- Used to format Lua code
    })
    require('mason-tool-installer').setup { ensure_installed = ensure_installed }

    for name, cfg in pairs(servers) do
      if next(cfg) then
        vim.lsp.config(name, cfg)
      end
    end

    -- Only the servers listed above are enabled (anything else installed in Mason stays off).
    require('mason-lspconfig').setup { ensure_installed = {}, automatic_enable = false }
    vim.lsp.enable(vim.tbl_keys(servers))
  end,
}
