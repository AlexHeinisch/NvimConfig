return {
  'mfussenegger/nvim-jdtls',
  -- Only with jdtls: its BufReadCmd for `*.class` / `jdt://` would otherwise intercept the
  -- `jar:` URIs that intellij-lsp's decompiler serves, and fail with "Must have a `jdtls` client".
  enabled = vim.g.java_lsp == 'jdtls',
  dependencies = {
    'mfussenegger/nvim-dap',
  },
}
