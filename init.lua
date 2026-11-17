-- Leader keys must be set before plugins load (otherwise the wrong leader is used).
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Track keymap usage (:KeymapReport). Must run before any keymap or plugin is defined.
require('util.keymap-stats').setup()

require 'config.options'
require 'config.keymaps'
require 'config.autocmds'
require 'config.lazy'
require('dashboard').setup()

-- vim: ts=2 sts=2 sw=2 et
