-- Completion: blink.cmp with LuaSnip as snippet engine.
require('luasnip').setup {}

--- @module 'blink.cmp'
--- @type blink.cmp.Config
local opts = {
  keymap = {
    -- 'default' (recommended) for mappings similar to built-in completions
    --   <c-y> to accept ([y]es) the completion.
    --    This will auto-import if your LSP supports it.
    --    This will expand snippets if the LSP sent a snippet.
    -- 'super-tab' for tab to accept
    -- 'enter' for enter to accept
    -- 'none' for no mappings
    --
    -- For an understanding of why the 'default' preset is recommended,
    -- you will need to read `:help ins-completion`
    --
    -- No, but seriously. Please read `:help ins-completion`, it is really good!
    --
    -- All presets have the following mappings:
    -- <tab>/<s-tab>: move to right/left of your snippet expansion
    -- <c-space>: Open menu or open docs if already open
    -- <c-n>/<c-p> or <up>/<down>: Select next/previous item
    -- <c-e>: Hide menu
    -- <c-k>: Toggle signature help
    --
    -- See :h blink-cmp-config-keymap for defining your own keymap
    preset = 'enter',

    -- <CR> accepts the selected item; after a lone `/**` in Java/Kotlin it expands the
    -- javadoc/KDoc skeleton (lua/snippets); otherwise it is a normal <CR>.
    ['<CR>'] = {
      'accept',
      function()
        return require('snippets.docblock').expand_on_enter(true)
      end,
      'fallback',
    },

    -- For more advanced Luasnip keymaps (e.g. selecting choice nodes, expansion) see:
    --    https://github.com/L3MON4D3/LuaSnip?tab=readme-ov-file#keymaps
  },

  appearance = {
    -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
    -- Adjusts spacing to ensure icons are aligned
    nerd_font_variant = 'mono',
  },

  completion = {
    -- By default, you may press `<c-space>` to show the documentation.
    -- Optionally, set `auto_show = true` to show the documentation after a delay.
    documentation = { auto_show = true, auto_show_delay_ms = 500, window = { winblend = 15 } },
    menu = { winblend = 15 },
  },

  sources = {
    default = { 'lsp', 'path', 'snippets' },
    -- lazydev (lua/plugins/lazydev.lua) is only offered in Lua buffers.
    per_filetype = { lua = { inherit_defaults = true, 'lazydev' } },
    providers = {
      lsp = {
        -- IntelliJ sends empty-string detail/documentation for items without docs. blink opens
        -- the docs window for any string, so it showed up blank; drop the empty values.
        transform_items = function(_, items)
          for _, item in ipairs(items) do
            if type(item.detail) == 'string' and item.detail:match '^%s*$' then
              item.detail = nil
            end
            local doc = item.documentation
            if type(doc) == 'string' and doc:match '^%s*$' then
              item.documentation = nil
            elseif type(doc) == 'table' and (doc.value or ''):match '^%s*$' then
              item.documentation = nil
            end
          end
          return items
        end,
      },
      lazydev = { module = 'lazydev.integrations.blink', score_offset = 100 },
    },
  },

  snippets = { preset = 'luasnip' },

  -- Rust fuzzy matcher (prebuilt binary is downloaded for the tagged release);
  -- falls back to the Lua implementation with a warning if it is unavailable.
  -- See :h blink-cmp-config-fuzzy
  fuzzy = { implementation = 'prefer_rust_with_warning' },

  -- Shows a signature help window while you type arguments for a function
  signature = { enabled = true, window = { winblend = 15 } },
}

require('blink.cmp').setup(opts)
