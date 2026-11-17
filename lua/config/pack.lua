-- [[ Plugins: native vim.pack ]]  (`:lua vim.pack.update()` reviews and applies updates; `:checkhealth vim.pack`)
-- The lockfile is nvim-pack-lock.json (tracked). Every plugin is loaded at startup; only the plugin
-- configuration modules in lua/plugins/ decide what runs when.

-- Runtime plugins that ship with Neovim and are not wanted (netrw is replaced by neo-tree).
for _, name in ipairs { 'loaded_gzip', 'loaded_tarPlugin', 'loaded_zipPlugin', 'loaded_tutor_mode_plugin', 'loaded_netrw', 'loaded_netrwPlugin' } do
  vim.g[name] = 1
end

-- Build steps. Registered before vim.pack.add(), so they also run for installs from the lockfile.
vim.api.nvim_create_autocmd('PackChanged', {
  group = vim.api.nvim_create_augroup('custom-pack-build', { clear = true }),
  desc = 'Run plugin build steps after install/update',
  callback = function(ev)
    local name, kind = ev.data.spec.name, ev.data.kind
    if kind ~= 'install' and kind ~= 'update' then
      return
    end
    local function make(args)
      if vim.fn.executable 'make' == 1 then
        vim.system(vim.list_extend({ 'make' }, args), { cwd = ev.data.path }, function(out)
          if out.code ~= 0 then
            vim.schedule(function()
              vim.notify(('%s: make failed\n%s'):format(name, out.stderr or ''), vim.log.levels.WARN)
            end)
          end
        end)
      end
    end
    if name == 'telescope-fzf-native.nvim' then
      make {}
    elseif name == 'LuaSnip' then
      make { 'install_jsregexp' } -- regex support in snippets
    elseif name == 'nvim-treesitter' and kind == 'update' then
      if not ev.data.active then
        vim.cmd.packadd 'nvim-treesitter'
      end
      vim.cmd 'TSUpdate'
    end
  end,
})

local function gh(repo)
  return 'https://github.com/' .. repo
end
local range = vim.version.range

-- Dependencies come before the plugins that need them (vim.pack does not resolve dependencies).
vim.pack.add({
  -- Libraries
  gh 'nvim-lua/plenary.nvim',
  gh 'MunifTanjim/nui.nvim',
  gh 'nvim-tree/nvim-web-devicons',

  -- Look and feel
  gh 'folke/tokyonight.nvim',
  gh 'folke/which-key.nvim',
  gh 'echasnovski/mini.nvim',

  -- Editing
  gh 'NMAC427/guess-indent.nvim', -- detect tabstop and shiftwidth
  gh 'folke/todo-comments.nvim',
  gh 'lewis6991/gitsigns.nvim',
  -- `main` is the rewrite that supports Neovim 0.12+ (`master` is frozen and breaks on it).
  { src = gh 'nvim-treesitter/nvim-treesitter', version = 'main' },
  { src = gh 'nvim-treesitter/nvim-treesitter-textobjects', version = 'main' },
  gh 'nvim-treesitter/nvim-treesitter-context',

  -- Navigation
  gh 'nvim-telescope/telescope.nvim',
  gh 'nvim-telescope/telescope-fzf-native.nvim',
  gh 'nvim-telescope/telescope-ui-select.nvim',
  { src = gh 'nvim-neo-tree/neo-tree.nvim', version = range '*' },
  { src = gh 'smart-splits-nvim/smart-splits.nvim', version = range '^3.0.0' },
  { src = gh 'ThePrimeagen/harpoon', version = 'harpoon2' },
  gh 'folke/trouble.nvim',

  -- LSP, completion, formatting
  gh 'folke/lazydev.nvim',
  { src = gh 'L3MON4D3/LuaSnip', version = range '2' },
  { src = gh 'saghen/blink.cmp', version = range '1' },
  gh 'mason-org/mason.nvim',
  gh 'mason-org/mason-lspconfig.nvim',
  gh 'WhoIsSethDaniel/mason-tool-installer.nvim',
  gh 'j-hui/fidget.nvim',
  gh 'neovim/nvim-lspconfig',
  gh 'stevearc/conform.nvim',

  -- Debugging and Java/Kotlin
  gh 'mfussenegger/nvim-dap',
  gh 'theHamsta/nvim-dap-virtual-text',
  gh 'JetBrains/intellij-lsp.nvim',

  -- Habits: hints for inefficient motions (`:Hardtime report`)
  gh 'm4xshen/hardtime.nvim',
}, { load = true, confirm = false })

-- Plugin configuration. Everything that is needed for the first screen (colorscheme, statusline, treesitter,
-- keymap triggers) runs now, in load order; the rest runs right after the first paint. That keeps startup at about
-- the lazy.nvim level while the plugins are still ready before the first keypress (keys typed meanwhile are queued).
local eager = { 'tokyonight', 'which-key', 'mini', 'guess-indent', 'gitsigns', 'nvim-treesitter', 'smart-splits', 'harpoon', 'lazydev', 'hardtime' }
-- Order matters: blink registers the LSP capabilities that nvim-lspconfig's servers pick up.
local deferred = {
  'todo-comments',
  'treesitter-textobjects',
  'treesitter-context',
  'telescope',
  'neo-tree',
  'trouble',
  'blink',
  'nvim-lspconfig',
  'conform',
  'debug',
  'intellij-lsp',
}

for _, module in ipairs(eager) do
  require('plugins.' .. module)
end

vim.schedule(function()
  for _, module in ipairs(deferred) do
    local ok, err = pcall(require, 'plugins.' .. module)
    if not ok then
      vim.notify('plugins.' .. module .. ': ' .. tostring(err), vim.log.levels.ERROR)
    end
  end
end)
