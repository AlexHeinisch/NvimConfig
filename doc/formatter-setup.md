# Formatter Setup

Formatting is handled by [conform.nvim](https://github.com/stevearc/conform.nvim).
Java formatting is delegated to jdtls (Eclipse JDT Language Server).

## Formatters by filetype

| Filetype | Formatter       |
|----------|-----------------|
| Lua      | `stylua`        |
| Rust     | `rustfmt`       |
| Java     | jdtls (LSP)     |

Indentation style (tabs vs spaces, width) is auto-detected per buffer by
`guess-indent.nvim` and passed to `stylua` and `rustfmt` automatically.

---

## Lua — stylua

### Global default

`~/.config/nvim/.stylua.toml` is the fallback config used for any Lua file
that does not belong to a project with its own config.

### Per-project override

Place a `.stylua.toml` at the **project root**. stylua walks up the directory
tree and uses the first config it finds, so the project file takes full
precedence over the global one.

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

## Java — jdtls (Eclipse formatter XML)

jdtls applies formatting using an Eclipse formatter profile.

### Global default

A pre-built profile is already present at:

```
~/.config/nvim/java-formatter.xml   ← iam-style profile
```

This profile was derived from the `iam` project conventions:
4-space indent, 160-char line limit, K&R braces, parameters column-aligned
with the opening parenthesis, each annotation on its own line.

It is loaded automatically whenever no project-local formatter is found.

To create your own, export a formatter profile from Eclipse
(`Window → Preferences → Java → Code Style → Formatter → Export`) or from
IntelliJ with the *Eclipse Code Formatter* plugin
(`Settings → Eclipse Code Formatter → Export`), then replace the file above.

### Per-project override

Place a formatter XML at one of these paths inside the **project root**:

```
<project-root>/.formatter.xml     ← checked first
<project-root>/formatter.xml
```

The jdtls config in `ftplugin/java.lua` checks for these files on startup and
uses the first one found, falling back to the global default.

> **Note:** jdtls is started once per project (keyed on `cwd`). If you add or
> change a formatter XML after the server is already running, restart it with
> `:LspRestart` (or close and reopen Neovim) for the new config to take effect.

### Obtaining a formatter XML

- **Google Java Format style**: use the XML from the
  [google-java-format](https://github.com/google/google-java-format) project.
- **Eclipse**: `Window → Preferences → Java → Code Style → Formatter → Export`.
- **IntelliJ**: install the *Eclipse Code Formatter* plugin and export from
  `Settings → Eclipse Code Formatter`.
- **Spring**: the Spring Framework ships `spring-javaformat` which includes an
  Eclipse XML.
