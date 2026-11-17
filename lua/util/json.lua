local M = {}

-- Recursively expands string values that contain valid JSON objects/arrays.
local python_script = [[
import json, sys

def expand(obj):
    if isinstance(obj, dict):
        return {k: expand(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [expand(v) for v in obj]
    elif isinstance(obj, str):
        try:
            parsed = json.loads(obj)
            if isinstance(parsed, (dict, list)):
                return expand(parsed)
        except Exception:
            pass
    return obj

data = json.loads(sys.stdin.read())
print(json.dumps(expand(data), indent=2, ensure_ascii=False))
]]

function M.format_json(line1, line2)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, line1 - 1, line2, false)
  local input = table.concat(lines, '\n')

  local result = vim.fn.systemlist({ 'python3', '-c', python_script }, input)
  if vim.v.shell_error ~= 0 then
    vim.notify('FormatJson: ' .. table.concat(result, '\n'), vim.log.levels.ERROR)
    return
  end

  vim.api.nvim_buf_set_lines(bufnr, line1 - 1, line2, false, result)
end

return M
