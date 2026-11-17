-- Background refresh: lazy.nvim updates, Mason updates, latest Neovim release, config smoke test.
-- Results are collected in `result`, then stored in state.data and the cache.
local state = require 'dashboard.state'
local M = {}

local function render()
  require('dashboard.render').render()
end

function M.refresh()
  if state.running then
    return
  end
  state.running = true
  render()

  local result = { checked = os.time() }
  local pending = 4
  local function done()
    pending = pending - 1
    if pending == 0 then
      vim.schedule(function()
        state.data = result
        state.running = false
        state.save()
        render()
      end)
    end
  end

  -- 1. lazy.nvim: fetch every plugin, list those behind upstream, and the new commits of intellij-lsp.
  local ok = pcall(function()
    require('lazy.manage').check({ show = false, clear = false }):wait(function()
      vim.schedule(function()
        local names, commits = {}, {}
        pcall(function()
          require('lazy.manage.checker').fast_check { report = false }
          for _, plugin in pairs(require('lazy.core.config').plugins) do
            local updates = plugin._.updates
            if updates then
              table.insert(names, plugin.name)
              if plugin.name == 'intellij-lsp.nvim' then
                local out = vim.system({ 'git', '-C', plugin.dir, 'log', '--format=%s', 'HEAD..' .. updates.to.commit }, { text = true }):wait()
                commits = vim.split(vim.trim(out.stdout or ''), '\n', { trimempty = true })
              end
            end
          end
        end)
        table.sort(names)
        result.plugins, result.intellij = names, commits
        done()
      end)
    end)
  end)
  if not ok then
    result.plugins, result.intellij = {}, {}
    done()
  end

  -- 2. Mason: refresh the registry, compare installed and latest versions.
  local mason_ok = pcall(function()
    local registry = require 'mason-registry'
    registry.update(function(success)
      vim.schedule(function()
        local outdated = {}
        if success then
          for _, pkg in ipairs(registry.get_installed_packages()) do
            local good, cur, latest = pcall(function()
              return pkg:get_installed_version(), pkg:get_latest_version()
            end)
            if good and cur and latest and cur ~= latest then
              table.insert(outdated, { name = pkg.name, current = cur, latest = latest })
            end
          end
        end
        table.sort(outdated, function(a, b)
          return a.name < b.name
        end)
        result.mason, result.mason_failed = outdated, not success
        done()
      end)
    end)
  end)
  if not mason_ok then
    result.mason, result.mason_failed = {}, true
    done()
  end

  -- 3. Latest Neovim release (GitHub). Only the public release endpoint is queried, no local data is sent.
  local curl_ok = pcall(
    vim.system,
    { 'curl', '-fsS', '--max-time', '15', '-H', 'Accept: application/vnd.github+json', 'https://api.github.com/repos/neovim/neovim/releases/latest' },
    { text = true },
    function(out)
      vim.schedule(function()
        local current = vim.version()
        local info = { current = ('%d.%d.%d'):format(current.major, current.minor, current.patch) }
        local ok, json = pcall(vim.json.decode, out.stdout or '')
        local latest = ok and type(json) == 'table' and type(json.tag_name) == 'string' and vim.version.parse(json.tag_name) or nil
        if latest then
          if vim.version.gt(latest, current) then
            info.latest = ('%d.%d.%d'):format(latest.major, latest.minor, latest.patch)
          end
        else
          info.failed = true
        end
        result.nvim = info
        done()
      end)
    end
  )
  if not curl_ok then
    result.nvim = { current = '?', failed = true }
    done()
  end

  -- 4. Config smoke test.
  local script = vim.fn.stdpath 'config' .. '/scripts/check.sh'
  local spawned = pcall(vim.system, { 'bash', script }, { text = true }, function(out)
    local text = vim.trim((out.stdout or '') .. (out.stderr or ''))
    local tail = vim.split(text, '\n', { trimempty = true })
    result.health = { ok = out.code == 0, lines = out.code == 0 and {} or vim.list_slice(tail, math.max(1, #tail - state.MAX_LIST + 1)) }
    done()
  end)
  if not spawned then
    done()
  end
end

return M
