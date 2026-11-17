-- IntelliJ IDEA's Java/Kotlin engine as a headless LSP server (`intellij-server`).
--
-- License: uses the Ultimate license from a license server. Either export
-- JETBRAINS_LICENSE_SERVER=<url> in your shell, or pick "Use a license server"
-- in the activation popup on first start (stored in ~/.config/JetBrains/IntelliJServer).
-- Check with :checkhealth intellij-lsp and :IntellijLspLicense.
--
-- Keymaps (Java/Kotlin buffers):
--   <leader>lr / lR / lw / lL   server control: restart, clear cache, reload config, license
--   <leader>dt        debug the test at the cursor (plugin; no breakpoint = plain run)
--   <leader>gh / gH   type hierarchy: subtypes / supertypes
--   <leader>gc / gC   call hierarchy: incoming / outgoing
--   <leader>dr        debug the main class at the cursor
--   <leader>db / dB   breakpoint / conditional breakpoint (debug.lua)
--   <leader>dc dn di do dq de dw dv   continue, step over/into/out, stop, evaluate, watch, panel (plugin)
return {
  'JetBrains/intellij-lsp.nvim',
  lazy = false, -- must load at startup so the project import starts before a buffer opens
  dependencies = { 'mfussenegger/nvim-dap' },
  opts = {
    default_sdk = vim.fn.expand '~/.sdkman/candidates/java/current', -- JDK for projects that don't configure one
    colorscheme = false, -- keep tokyonight
    -- blink.cmp does the completion; the plugin's built-in menu would show a second,
    -- opaque, differently sorted popup.
    autotrigger = false,
    word_triggers = false,
    enter_accepts_completion = false,
    completeopt = false,
    -- keymaps stay on (default): since the 271 update `keymaps = false` also drops the run/test/debug
    -- maps. The hierarchy/symbol maps the plugin adds under <leader>t/c/w are removed again below.
    region = 'europe',
    data_sharing = 'none',
    -- accept_eula = true, -- uncomment after reading EULA.txt to skip the prompt on new machines
  },
  config = function(_, opts)
    -- debug panel: Locals and Watches above the Call stack
    require('custom.utils.intellij-debug-layout').apply()
    require('intellij-lsp').setup(opts)

    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('custom-intellij-lsp-keymaps', { clear = true }),
      callback = function(event)
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if not client or client.name ~= 'intellij' then
          return
        end
        local buf = event.buf

        -- intellij-server ignores lombok.config, so @CustomLog classes get false errors.
        -- See lua/custom/utils/intellij-lombok-workaround.lua for the cause and when to remove it.
        require('custom.utils.intellij-lombok-workaround').apply(client)

        -- The plugin sets its run/debug maps in on_attach, which runs after LspAttach,
        -- so the overrides are scheduled to land after them.
        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(buf) then
            return
          end
          -- on_attach enables the native LSP completion; turn it off again in favour of blink.cmp.
          pcall(vim.lsp.completion.enable, false, client.id, buf)
          local function map(lhs, rhs, desc)
            vim.keymap.set('n', lhs, rhs, { buffer = buf, desc = desc })
          end
          local function unmap(lhs)
            pcall(vim.keymap.del, 'n', lhs, { buffer = buf })
          end

          -- Breakpoints stay on <leader>db / <leader>dB (same nvim-dap breakpoints).
          unmap '<leader>b'
          unmap '<leader>B'
          unmap '<leader>rd'
          -- Debugging with no breakpoint set is a plain run, so the run maps are redundant.
          for _, lhs in ipairs { '<leader>rr', '<leader>rl', '<leader>rt', '<leader>rT' } do
            unmap(lhs)
          end
          for _, lhs in ipairs { '<leader>ts', '<leader>tu', '<leader>ci', '<leader>co', '<leader>ws' } do
            unmap(lhs)
          end

          local editor = require 'intellij-lsp.editor'
          map('<leader>gh', function()
            editor.type_hierarchy 'subtypes'
          end, 'LSP: Type [H]ierarchy (subtypes)')
          map('<leader>gH', function()
            editor.type_hierarchy 'supertypes'
          end, 'LSP: Type [H]ierarchy (supertypes)')
          map('<leader>gc', function()
            editor.call_hierarchy 'incoming'
          end, 'LSP: [C]all hierarchy (incoming)')
          map('<leader>gC', function()
            editor.call_hierarchy 'outgoing'
          end, 'LSP: [C]all hierarchy (outgoing)')

          map('<leader>dr', function()
            require('intellij-lsp.run').run_at_cursor(false)
          end, 'Debug: [R]un class at cursor')

          -- <leader>l: IntelliJ server commands (the :IntellijLsp* user commands)
          map('<leader>lr', '<Cmd>IntellijLspRestart<CR>', 'IntelliJ: [R]estart server')
          map('<leader>lR', '<Cmd>IntellijLspClearCache<CR>', 'IntelliJ: clear index and [R]estart')
          map('<leader>lw', '<Cmd>IntellijLspReload<CR>', 'IntelliJ: re-apply config (re[w]ork)')
          map('<leader>lL', '<Cmd>IntellijLspLicense<CR>', 'IntelliJ: [L]icense')
        end)
      end,
    })
  end,
}
