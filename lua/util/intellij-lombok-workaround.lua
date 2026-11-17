-- Workaround: false Lombok diagnostics from intellij-server (JetBrains/intellij-lsp.nvim)
--
-- PROBLEM
--   intellij-server (checked with build 263.7084.0) never applies lombok.config. Every class
--   annotated with @CustomLog therefore reports two false errors:
--     - "The @CustomLog is not configured correctly; please set log.custom.declaration in lombok.config."
--     - "Cannot resolve symbol 'log'" on each use of the generated `log` field
--   Desktop IntelliJ and the Maven/javac build are fine: this only affects the language server.
--
-- ROOT CAUSE (found by disassembling the server bundle)
--   The server replaces IntelliJ's file type manager with its own
--   `com.jetbrains.analyzer.bootstrap.AnalyzerFileTypeManager` (lib/language-server.analyzer.jar),
--   which only matches file types by EXTENSION:
--     getFileTypeByFile(f)        -> getFileTypeByFileName(f.name)
--     getFileTypeByFileName(name) -> getFileTypeByExtension(getExtension(name))   -- "config"
--     associate(type, matcher)    -> throws UnsupportedOperationException
--   File types are registered with `registerFileType(type, bean.extensions ?: bean.fileNames)`.
--   The Lombok plugin declares its type by exact name (`fileNames="lombok.config"`), so it is
--   stored under the key "lombok.config" while lookups ask for "config". lombok.config is
--   classified as an unknown file type, Lombok's LombokConfigIndex (which only accepts its own
--   file type) stays empty, and ConfigDiscovery finds no setting anywhere. This was confirmed
--   by placing lombok.config next to the class: same errors. It also means the other settings
--   (lombok.accessors.chain, lombok.equalsAndHashCode.callSuper) are ignored by the server.
--
-- WHY NOT FIX IT LOCALLY
--   No file name can hit the "lombok.config" key: an extension never contains a dot. A user
--   plugin that maps the "config" extension to Lombok's type would work, but intellij-server
--   only loads the plugins shipped inside its bundle (com.intellij.ls.server.BundledPlugins), and
--   editing the licensed bundle is off the table (EULA, overwritten on every update).
--
-- WHAT THIS DOES
--   Drops exactly those two messages from the `intellij` client only: the @CustomLog message
--   always, and "Cannot resolve symbol 'log'" only in buffers that use @CustomLog. Real errors
--   are untouched. Known gap that remains: no completion on `log.`.
--
-- REMOVE when JetBrains fixes file name matching for file types in intellij-server: delete this
-- file and its call in lua/plugins/intellij-lsp.lua, restart, and check that
-- RealmAttributeValidatorImpl (iam repo) is clean without it.
local M = {}

local CUSTOM_LOG_MSG = 'The @CustomLog is not configured correctly'
local UNRESOLVED_LOG_MSG = "Cannot resolve symbol 'log'"

local function uses_custom_log(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_loaded(bufnr) then
    return false
  end
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    if line:find('@CustomLog', 1, true) or line:find('@lombok.CustomLog', 1, true) then
      return true
    end
  end
  return false
end

local function filter(diagnostics, bufnr)
  if not diagnostics or #diagnostics == 0 then
    return diagnostics
  end
  local custom_log -- computed lazily, only when an unresolved `log` shows up
  return vim.tbl_filter(function(d)
    local msg = d.message or ''
    if vim.startswith(msg, CUSTOM_LOG_MSG) then
      return false
    end
    if msg == UNRESOLVED_LOG_MSG then
      if custom_log == nil then
        custom_log = uses_custom_log(bufnr)
      end
      return not custom_log
    end
    return true
  end, diagnostics)
end

--- Wraps the client's diagnostic handlers (pull and push). Neovim prefers `client.handlers` over
--- `vim.lsp.handlers`, so other servers are unaffected; an existing client handler (the plugin
--- wraps `textDocument/diagnostic` for licensing) is kept and called after filtering.
--- @param client vim.lsp.Client
function M.apply(client)
  if client._lombok_workaround then
    return
  end
  client._lombok_workaround = true

  local pull = 'textDocument/diagnostic'
  local orig_pull = client.handlers[pull] or vim.lsp.handlers[pull]
  client.handlers[pull] = function(err, result, ctx, config)
    if result and result.items then
      result.items = filter(result.items, ctx.bufnr)
    end
    return orig_pull(err, result, ctx, config)
  end

  local push = 'textDocument/publishDiagnostics'
  local orig_push = client.handlers[push] or vim.lsp.handlers[push]
  client.handlers[push] = function(err, result, ctx, config)
    if result and result.diagnostics then
      local bufnr = vim.uri_to_bufnr(result.uri)
      result.diagnostics = filter(result.diagnostics, bufnr)
    end
    return orig_push(err, result, ctx, config)
  end
end

return M
