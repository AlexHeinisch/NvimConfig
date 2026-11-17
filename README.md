# Neovim config

Started from [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) (see `LICENSE.md`), now tuned for Java/Kotlin via
[intellij-lsp.nvim](https://github.com/JetBrains/intellij-lsp.nvim).

- `init.lua` loads `lua/config/{options,keymaps,autocmds,lazy}.lua`.
- `lua/custom/plugins/` has one spec per plugin; `lua/custom/utils/` and `lua/custom/snippets/` hold local helpers.
- Requires Neovim 0.12+, `git`, `make`, a C compiler, `ripgrep`, `fd`, the `tree-sitter` CLI (>= 0.26) and a Nerd Font.
- Smoke test: `scripts/check.sh` (loads every module, checks the doc-comment snippets). Format with `stylua .`.
