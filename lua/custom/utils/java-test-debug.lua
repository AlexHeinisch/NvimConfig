-- Debug JVM tests with intellij-lsp.nvim, which has no test runner of its own.
--
-- The build tool runs the tests in a terminal split with the test JVM waiting for a debugger on
-- port 5005 (Maven: -Dmaven.surefire.debug, Gradle: --debug-jvm). As soon as it prints
-- "Listening for transport dt_socket", nvim-dap attaches through the plugin's own `intellij_jvm`
-- adapter, so breakpoints, the debug panel (<leader>dv) and stepping work as for a normal launch.
local M = {}

local PORT = 5005
local ADAPTER = 'intellij_jvm' -- registered by intellij-lsp.nvim's run.setup()

local job -- the build tool's terminal job, one at a time

local function notify(msg, level)
  vim.notify('Java tests: ' .. msg, level or vim.log.levels.INFO)
end

--- Nearest directory between `file` and `root` (inclusive) that holds one of `markers`.
local function module_dir(file, root, markers)
  for dir in vim.fs.parents(file) do
    for _, m in ipairs(markers) do
      if vim.uv.fs_stat(dir .. '/' .. m) then
        return dir
      end
    end
    if dir == root then
      break
    end
  end
  return root
end

local function exists(path)
  return vim.uv.fs_stat(path) ~= nil
end

--- Fully qualified name of the top-level class in the buffer, e.g. `com.acme.FooTest`.
local function test_class(bufnr)
  local pkg
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, 50, false)) do
    pkg = line:match('^%s*package%s+([%w_.]+)')
    if pkg then
      break
    end
  end
  local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':t:r')
  return pkg and (pkg .. '.' .. name) or name
end

--- Builds the command line and working directory for the project `file` belongs to.
--- @param scope 'class'|'all'
local function build_command(file, root, scope, bufnr)
  local fqcn = scope == 'class' and test_class(bufnr) or nil

  if exists(root .. '/pom.xml') then
    local mvn = exists(root .. '/mvnw') and './mvnw' or 'mvn'
    local cmd = { mvn, 'test', '-Dmaven.surefire.debug', '-Dsurefire.failIfNoSpecifiedTests=false' }
    local mod = module_dir(file, root, { 'pom.xml' })
    if mod ~= root then
      vim.list_extend(cmd, { '-pl', vim.fs.relpath(root, mod), '-am' })
    end
    if fqcn then
      table.insert(cmd, '-Dtest=' .. fqcn)
    end
    return cmd
  end

  local gradle_markers = { 'build.gradle', 'build.gradle.kts', 'settings.gradle', 'settings.gradle.kts' }
  for _, m in ipairs(gradle_markers) do
    if exists(root .. '/' .. m) then
      local gradle = exists(root .. '/gradlew') and './gradlew' or 'gradle'
      local mod = module_dir(file, root, { 'build.gradle', 'build.gradle.kts' })
      local task = 'test'
      if mod ~= root then
        task = ':' .. vim.fs.relpath(root, mod):gsub('/', ':') .. ':test'
      end
      local cmd = { gradle, task, '--debug-jvm' }
      if fqcn then
        vim.list_extend(cmd, { '--tests', fqcn })
      end
      return cmd
    end
  end
end

--- Attaches nvim-dap to the waiting test JVM through the IntelliJ server's debugger.
local function attach(client, uri, root, name)
  -- The test classpath helps the debugger map sources; attach still works without it.
  client:request('workspace/executeCommand', {
    command = 'intellij.java.resolveLaunch',
    arguments = { { uri = uri } },
  }, function(_, paths)
    vim.schedule(function()
      require('dap').run({
        type = ADAPTER,
        request = 'attach',
        name = name,
        port = PORT,
        classPaths = paths and paths.classpath or {},
        cwd = root,
        intellijClientId = client.id, -- routing for the plugin's adapter, stripped before sending
      })
    end)
  end)
end

--- Runs the tests of the current class (`'class'`) or module (`'all'`) under the debugger.
--- @param scope 'class'|'all'
function M.debug(scope)
  local ok_dap = pcall(require, 'dap')
  if not ok_dap then
    return notify('nvim-dap is not installed', vim.log.levels.ERROR)
  end
  if job then
    return notify('a test run is still active; stop it with <leader>dQ', vim.log.levels.WARN)
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(bufnr)
  local client = require('intellij-lsp.client').find_ancestor_client(file)
  if not client then
    return notify('no IntelliJ server for this file', vim.log.levels.ERROR)
  end
  local root = client.config.root_dir

  local cmd = build_command(file, root, scope, bufnr)
  if not cmd then
    return notify('no Maven or Gradle build found in ' .. root, vim.log.levels.ERROR)
  end

  local name = scope == 'class' and ('Tests: ' .. test_class(bufnr)) or 'Tests: all'
  local uri = vim.uri_from_bufnr(bufnr)
  local attached = false
  local src_win = vim.api.nvim_get_current_win()

  vim.cmd('botright 15new')
  local term_buf = vim.api.nvim_get_current_buf()
  vim.bo[term_buf].bufhidden = 'wipe'
  job = vim.fn.jobstart(cmd, {
    term = true,
    cwd = root,
    -- Every forked test JVM waits on the port (Maven -am forks one per module with tests),
    -- so attach again each time one announces itself.
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if line:find('Listening for transport dt_socket', 1, true) then
          attached = true
          attach(client, uri, root, name)
        end
      end
    end,
    on_exit = function(_, code)
      job = nil
      vim.schedule(function()
        if not attached then
          notify('build exited (' .. code .. ') before a test JVM started', vim.log.levels.WARN)
        else
          notify(code == 0 and 'tests passed' or 'tests failed (exit ' .. code .. ')', code == 0 and vim.log.levels.INFO or vim.log.levels.WARN)
        end
      end)
    end,
  })
  vim.api.nvim_buf_set_name(term_buf, 'java-tests://' .. table.concat(cmd, ' '))
  notify(table.concat(cmd, ' '))
  -- Stay in the code so breakpoints can still be set while the build runs.
  vim.api.nvim_set_current_win(src_win)
end

--- Stops the test run and its debug session.
function M.stop()
  local dap = require('dap')
  if dap.session() then
    dap.terminate()
  end
  if job then
    vim.fn.jobstop(job)
  end
end

return M
