-- Pixel-font title and its highlight groups.
local M = {}

-- 5x5 pixel font for the title
local GLYPHS = {
  N = { 'X...X', 'XX..X', 'X.X.X', 'X..XX', 'X...X' },
  E = { 'XXXXX', 'X....', 'XXXX.', 'X....', 'XXXXX' },
  O = { '.XXX.', 'X...X', 'X...X', 'X...X', '.XXX.' },
  V = { 'X...X', 'X...X', 'X...X', '.X.X.', '..X..' },
  I = { 'XXXXX', '..X..', '..X..', '..X..', 'XXXXX' },
  M = { 'X...X', 'XX.XX', 'X.X.X', 'X...X', 'X...X' },
}
-- Solarized accents, one per pixel row, plus a dim drop shadow. Re-applied on :colorscheme.
local LOGO_COLORS = { '#b58900', '#cb4b16', '#dc322f', '#d33682', '#6c71c4' }
local function define_highlights()
  for i, color in ipairs(LOGO_COLORS) do
    vim.api.nvim_set_hl(0, 'DashboardLogo' .. i, { fg = color, bold = true })
  end
  vim.api.nvim_set_hl(0, 'DashboardLogoShadow', { fg = '#2a4a55' })
  vim.api.nvim_set_hl(0, 'DashboardVersion', { fg = '#839496', italic = true })
  vim.api.nvim_set_hl(0, 'DashboardSelected', { bg = '#073642', bold = true })
end

---@param width integer window width; wide windows get 2-column pixels (square-looking)
---@return string[] rows, table[][] segments # text rows and per-row { start_byte, end_byte, group } runs
local function logo_rows(width)
  local scale = width >= 84 and 2 or 1
  local letters = { 'N', 'E', 'O', 'V', 'I', 'M' }
  -- Pixel grid with a one-pixel drop shadow to the bottom right.
  local grid = {}
  for r = 1, 6 do
    grid[r] = {}
  end
  local col = 0
  for _, ch in ipairs(letters) do
    for r = 1, 5 do
      for c = 1, 5 do
        if GLYPHS[ch][r]:sub(c, c) == 'X' then
          grid[r][col + c] = 'X'
        end
      end
    end
    col = col + 6
  end
  for r = 1, 5 do
    for c = 1, col do
      if grid[r][c] == 'X' and not grid[r + 1][c + 1] then
        grid[r + 1][c + 1] = grid[r + 1][c + 1] or 'S'
      end
    end
  end
  local rows, segments = {}, {}
  for r = 1, 6 do
    local text, segs = '', {}
    for c = 1, col + 1 do
      local cell = grid[r][c]
      local piece = cell == 'X' and ('█'):rep(scale) or cell == 'S' and ('░'):rep(scale) or (' '):rep(scale)
      if cell then
        table.insert(segs, { #text, #text + #piece, cell == 'X' and ('DashboardLogo' .. r) or 'DashboardLogoShadow' })
      end
      text = text .. piece
    end
    rows[r], segments[r] = text, segs
  end
  return rows, segments
end

M.define_highlights = define_highlights
M.rows = logo_rows

return M
