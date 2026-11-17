#!/usr/bin/env bash
# Smoke test: starts Neovim headless with this config, loads every module under lua/, and runs the
# snippet expectations. Exit code 1 and a list of failures when anything is wrong.
set -euo pipefail
cd "$(dirname "$0")/.."
nvim --headless "+lua vim.defer_fn(function() dofile('scripts/check.lua') end, 1500)" 2>&1
