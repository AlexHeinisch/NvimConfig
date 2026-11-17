# Neovim config

Started from [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) (see `LICENSE.md`), now tuned for Java/Kotlin via
[intellij-lsp.nvim](https://github.com/JetBrains/intellij-lsp.nvim).

- `init.lua` loads `lua/config/{options,keymaps,autocmds,pack}.lua`. Plugins are managed by Neovim's built-in `vim.pack` (`config/pack.lua` lists them; lockfile `nvim-pack-lock.json`; update with `:lua vim.pack.update()`).
- `lua/plugins/` has one configuration module per plugin (required in order by `config/pack.lua`); `lua/util/`, `lua/snippets/` and `lua/dashboard/` hold local helpers.
- Requires Neovim 0.12+, `git`, `make`, a C compiler, `ripgrep`, `fd`, the `tree-sitter` CLI (>= 0.26) and a Nerd Font.
- Smoke test: `scripts/check.sh` (loads every module, checks the doc-comment snippets). Format with `stylua .`.
