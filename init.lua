-- Leader keys must be set before plugins load (otherwise the wrong leader is used).
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true

-- Track keymap usage (:KeymapReport). Must run before any keymap or plugin is defined.
require('custom.utils.keymap-stats').setup()

require 'config.options'
require 'config.keymaps'
require 'config.autocmds'
require 'config.lazy'
require('custom.dashboard').setup()

-- vim: ts=2 sts=2 sw=2 et
