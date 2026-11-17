# Formatter Setup

Formatting is handled by [conform.nvim](https://github.com/stevearc/conform.nvim).
Java and Kotlin formatting is delegated to the IntelliJ language server (intellij-lsp.nvim).

## Formatters by filetype

| Filetype | Formatter       |
|----------|-----------------|
| Lua      | `stylua`        |
| Rust     | `rustfmt`       |
| Java     | IntelliJ server (LSP, `lsp_format = 'prefer'`) |

Indentation style (tabs vs spaces, width) is auto-detected per buffer by
`guess-indent.nvim` and passed to `stylua` and `rustfmt` automatically.
Those indentation flags are passed on the command line, so they override the
indent settings of any `.stylua.toml`; other keys (`column_width`, `quote_style`, ...) still come from the file.

---

## Lua — stylua

### Global default

`~/.config/nvim/.stylua.toml` is the fallback config used for any Lua file
that does not belong to a project with its own config.

### Per-project override

Place a `.stylua.toml` at the **project root**. stylua walks up the directory
tree and uses the first config it finds, so the project file replaces the
global one for every key except the indentation (see above).

```toml
# project/.stylua.toml
column_width = 120
indent_type = "Spaces"
indent_width = 4
quote_style = "AutoPreferDouble"
```

---

## Rust — rustfmt

### Global default

`rustfmt` uses its built-in defaults when no config is present. To set a
global default, create `~/.config/rustfmt/rustfmt.toml`.

### Per-project override

Place a `rustfmt.toml` (or `.rustfmt.toml`) at the **project root** or in any
parent directory. rustfmt walks up and uses the first file it finds.

```toml
# project/rustfmt.toml
max_width = 100
tab_spaces = 4
hard_tabs = false
```

---

## Java / Kotlin — IntelliJ language server

`<leader>f` asks the `intellij` client to format (`java = { lsp_format = 'prefer' }` in
`lua/plugins/conform.lua`). The code style comes from the server's own project settings, so
there is no formatter profile in this config. Formatting is not run on save.
