-- Things the dashboard can do: Enter on a line, Mason updates, floating logs.
local state = require 'dashboard.state'
local M = {}

-- render and refresh call back into this module, so the render module is required lazily.
local function render()
  require('dashboard.render').render()
end

function M.update_mason(names)
  local registry = require 'mason-registry'
  for _, name in ipairs(names) do
    if not state.updating[name] then
      state.updating[name] = 'running'
      local ok = pcall(function()
        registry.get_package(name):install({}, function(success)
          vim.schedule(function()
            if success then
              state.updating[name] = nil
              state.data.mason = vim.tbl_filter(function(entry)
                return entry.name ~= name
              end, state.data.mason or {})
              state.save()
            else
              state.updating[name] = 'failed'
            end
            render()
          end)
        end)
      end)
      if not ok then
        state.updating[name] = 'failed'
      end
    end
  end
  render()
end

---@param title string
---@param lines string[]
local function float(title, lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = 'wipe'
  local width = math.min(100, vim.o.columns - 8)
  local height = math.min(#lines, vim.o.lines - 8)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = math.max(height, 1),
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' ' .. title .. ' ',
    title_pos = 'center',
  })
  vim.wo[win].wrap = true
  for _, key in ipairs { 'q', '<Esc>', '<CR>' } do
    vim.keymap.set('n', key, '<Cmd>close<CR>', { buffer = buf, nowait = true, silent = true })
  end
end

function M.open_lazy()
  vim.cmd 'Lazy'
end

function M.show_intellij_log()
  local plugin = require('lazy.core.config').plugins['intellij-lsp.nvim']
  if not plugin then
    return
  end
  vim.system({ 'git', '-C', plugin.dir, 'log', '--date=short', '--format=%h  %cd  %s%n%b', 'HEAD..origin/HEAD' }, { text = true }, function(out)
    vim.schedule(function()
      local lines = vim.split(vim.trim(out.stdout or ''), '\n')
      float('intellij-lsp.nvim: new upstream commits', lines)
    end)
  end)
end

function M.run_check()
  vim.notify 'Running config check…'
  vim.system({ 'bash', vim.fn.stdpath 'config' .. '/scripts/check.sh' }, { text = true }, function(out)
    vim.schedule(function()
      local text = vim.trim((out.stdout or '') .. (out.stderr or ''))
      local lines = vim.split(text, '\n')
      state.data.health = { ok = out.code == 0, lines = out.code == 0 and {} or vim.list_slice(lines, math.max(1, #lines - state.MAX_LIST + 1)) }
      state.save()
      render()
      float(out.code == 0 and 'config check: passed' or 'config check: FAILED', lines)
    end)
  end)
end

function M.open_release(version)
  vim.ui.open('https://github.com/neovim/neovim/releases/tag/v' .. version)
end

function M.open_harpoon_menu()
  vim.api.nvim_feedkeys(vim.keycode '<leader>M', 'm', false)
end

return M
