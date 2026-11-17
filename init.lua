local init_start = vim.uv.hrtime()

-- Leader keys must be set before plugins load (otherwise the wrong leader is used).
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Track keymap usage (:KeymapReport). Must run before any keymap or plugin is defined.
require('util.keymap-stats').setup()

require 'config.options'
require 'config.keymaps'
require 'config.autocmds'
require 'config.pack'
require('dashboard').setup()

-- Time spent in this file (plugin loading included), for the dashboard footer.
vim.g.init_ms = (vim.uv.hrtime() - init_start) / 1e6

-- vim: ts=2 sts=2 sw=2 et
