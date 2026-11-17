---@diagnostic disable-next-line: missing-fields
require('tokyonight').setup {
  transparent = true,
  styles = {
    comments = { italic = true },
    sidebars = 'transparent', -- neo-tree, trouble, dap-ui, help, quickfix
    floats = 'transparent', -- hover, telescope, which-key, ...
  },
  -- Statusline in herdr's solarized tab-bar colors (bar #002b36, active tab #268bd2).
  on_highlights = function(hl)
    local bar, text, dim, bright = '#002b36', '#657b83', '#586e75', '#93a1a1'
    hl.StatusLine = { bg = bar, fg = text }
    hl.StatusLineNC = { bg = bar, fg = dim }
    hl.MiniStatuslineFilename = { bg = bar, fg = bright }
    hl.MiniStatuslineFileinfo = { bg = bar, fg = text }
    hl.MiniStatuslineDevinfo = { bg = bar, fg = text }
    hl.MiniStatuslineInactive = { bg = bar, fg = dim }
    -- Mode pill: normal = herdr's active-tab blue, other modes = solarized accents
    local modes = {
      Normal = '#268bd2',
      Insert = '#859900',
      Visual = '#d33682',
      Replace = '#dc322f',
      Command = '#b58900',
      Other = '#2aa198',
    }
    for mode, color in pairs(modes) do
      hl['MiniStatuslineMode' .. mode] = { bg = color, fg = bar, bold = true }
    end
  end,
}

-- Load the colorscheme here.
-- Like many other themes, this one has different styles, and you could load
-- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
vim.cmd.colorscheme 'tokyonight-night'
