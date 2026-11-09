-- IntelliJ IDEA's Java/Kotlin engine as a headless LSP server (`intellij-server`).
-- Active when vim.g.java_lsp == 'intellij' (see init.lua); otherwise ftplugin/java.lua starts jdtls.
--
-- License: uses the Ultimate license from a license server. Either export
-- JETBRAINS_LICENSE_SERVER=<url> in your shell, or pick "Use a license server"
-- in the activation popup on first start (stored in ~/.config/JetBrains/IntelliJServer).
-- Check with :checkhealth intellij-lsp and :IntellijLspLicense.
--
-- Keymaps (Java/Kotlin buffers):
--   <leader>gh / gH   type hierarchy: subtypes / supertypes
--   <leader>gc / gC   call hierarchy: incoming / outgoing
--   <leader>dr        debug the main class at the cursor
--   <leader>dT / dA   debug the tests of this class / of the whole module (attaches on port 5005)
--   <leader>dQ        stop the test run
--   <leader>db / dB   breakpoint / conditional breakpoint (kickstart debug.lua)
--   <leader>dc dn di do dq de dw dv   continue, step over/into/out, stop, evaluate, watch, panel (plugin)
--   <leader>rr / rl   run the main class / the code lens on this line (plugin)
return {
  'JetBrains/intellij-lsp.nvim',
  enabled = vim.g.java_lsp == 'intellij',
  lazy = false, -- must load at startup so the project import starts before a buffer opens
  dependencies = { 'mfussenegger/nvim-dap' },
  opts = {
    default_sdk = vim.fn.expand '~/.sdkman/candidates/java/current', -- JDK for projects that don't configure one
    colorscheme = false, -- keep tokyonight
    keymaps = false, -- hierarchy maps live under <leader>g below
    region = 'europe',
    data_sharing = 'none',
    -- accept_eula = true, -- uncomment after reading EULA.txt to skip the prompt on new machines
  },
  config = function(_, opts)
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

          local editor = require 'intellij-lsp.editor'
          map('<leader>gh', function() editor.type_hierarchy 'subtypes' end, 'LSP: Type [H]ierarchy (subtypes)')
          map('<leader>gH', function() editor.type_hierarchy 'supertypes' end, 'LSP: Type [H]ierarchy (supertypes)')
          map('<leader>gc', function() editor.call_hierarchy 'incoming' end, 'LSP: [C]all hierarchy (incoming)')
          map('<leader>gC', function() editor.call_hierarchy 'outgoing' end, 'LSP: [C]all hierarchy (outgoing)')

          map('<leader>dr', function() require('intellij-lsp.run').run_at_cursor(false) end, 'Debug: [R]un class at cursor')

          local tests = require 'custom.utils.java-test-debug'
          map('<leader>dT', function() tests.debug 'class' end, 'Debug: [T]ests of this class')
          map('<leader>dA', function() tests.debug 'all' end, 'Debug: [A]ll tests of this module')
          map('<leader>dQ', tests.stop, 'Debug: [Q]uit test run')
        end)
      end,
    })
  end,
}
