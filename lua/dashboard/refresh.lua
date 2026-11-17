-- Background refresh: plugin updates (git), Mason updates, latest Neovim release, config smoke test.
-- Results are collected in `result`, then stored in state.data and the cache.
local state = require 'dashboard.state'
local M = {}

local function render()
  require('dashboard.render').render()
end

local function git(path, args, cb)
  local ok = pcall(vim.system, vim.list_extend({ 'git', '-C', path }, args), { text = true }, function(out)
    cb(out.code == 0 and vim.trim(out.stdout or '') or nil)
  end)
  if not ok then
    cb(nil)
  end
end

--- Newest tag of `tags` (a newline separated `git tag` listing) inside the version range, or nil.
local function newest_tag_in(range, tags)
  local best
  for tag in vim.gsplit(tags, '\n', { trimempty = true }) do
    local v = vim.version.parse(tag)
    if v and range:has(v) and (not best or vim.version.gt(v, best.v)) then
      best = { v = v, tag = tag }
    end
  end
  return best and best.tag
end

--- Subjects of the commits a plugin is behind its target (`version`: range, branch/tag/hash, or default branch).
--- @param plugin vim.pack.PlugData
--- @param cb fun(subjects: string[]|nil) nil when the check failed
local function commits_behind(plugin, cb)
  local path, version = plugin.path, plugin.spec.version
  git(path, { 'fetch', '--quiet', '--tags', '--force', 'origin' }, function(fetched)
    if not fetched then
      return cb(nil)
    end
    local function log(target)
      git(path, { 'log', '--format=%s', 'HEAD..' .. target }, function(out)
        cb(out and vim.split(out, '\n', { trimempty = true }) or nil)
      end)
    end
    if type(version) == 'table' then
      git(path, { 'tag', '--list' }, function(tags)
        local tag = tags and newest_tag_in(version, tags)
        if tag then
          log(tag)
        else
          cb {}
        end
      end)
    elseif type(version) == 'string' then
      git(path, { 'rev-parse', '--verify', '--quiet', 'origin/' .. version }, function(branch)
        log(branch and ('origin/' .. version) or version)
      end)
    else
      log 'origin/HEAD'
    end
  end)
end

--- Fetches all plugins in parallel. `cb(names, intellij_commits)`: names of plugins with updates (sorted).
function M.check_plugins(cb)
  local plugins = vim.pack.get(nil, { info = false })
  local pending, names, intellij = #plugins, {}, {}
  if pending == 0 then
    return cb(names, intellij)
  end
  for _, plugin in ipairs(plugins) do
    commits_behind(plugin, function(subjects)
      vim.schedule(function()
        if subjects and #subjects > 0 then
          table.insert(names, plugin.spec.name)
          if plugin.spec.name == 'intellij-lsp.nvim' then
            intellij = subjects
          end
        end
        pending = pending - 1
        if pending == 0 then
          table.sort(names)
          cb(names, intellij)
        end
      end)
    end)
  end
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

  -- 1. Plugins (vim.pack): fetch every plugin and list those behind the revision their `version` points to,
  --    plus the new commits of intellij-lsp.
  local ok = pcall(function()
    M.check_plugins(function(names, commits)
      result.plugins, result.intellij = names, commits
      done()
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
