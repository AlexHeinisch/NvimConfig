#!/usr/bin/env bash
# Smoke test: starts Neovim headless with this config, loads every module under lua/, and runs the
# snippet expectations. Exit code 1 and a list of failures when anything is wrong.
set -euo pipefail
cd "$(dirname "$0")/.."
# Run the checks right after VimEnter (User VeryLazy never fires headless); the timer is only a fallback.
nvim --headless "+lua local ran = false; local function run() if not ran then ran = true; dofile('scripts/check.lua') end end; vim.api.nvim_create_autocmd('VimEnter', { once = true, callback = function() vim.schedule(run) end }); vim.defer_fn(run, 10000)" 2>&1
