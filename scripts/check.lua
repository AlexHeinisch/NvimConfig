-- Run by scripts/check.sh inside a fully started Neovim. Collects failures, prints them, exits 1.
local failures = {}
local function fail(msg) table.insert(failures, msg) end

-- 1. Every module under lua/ loads.
local root = vim.fn.stdpath 'config' .. '/lua'
for _, file in ipairs(vim.fn.globpath(root, '**/*.lua', false, true)) do
  local mod = file:sub(#root + 2, -5):gsub('/init$', ''):gsub('/', '.')
  local ok, err = pcall(require, mod)
  if not ok then fail(('require %s: %s'):format(mod, err)) end
end

-- 2. Messages raised during startup.
if vim.v.errmsg ~= '' then fail('v:errmsg: ' .. vim.v.errmsg) end

-- 3. Doc comment tags per declaration.
local cases = {
  { 'java', 'public <T> List<T> find(final String a, int... rest) throws IOException {', { '@param <T>', '@param a', '@param rest', '@return', '@throws IOException' } },
  { 'java', 'void run() {}', {} },
  { 'java', 'public record P(int a, String b) {}', { '@param a', '@param b' } },
  { 'java', 'public Foo(int x) {}', { '@param x' } },
  { 'kotlin', 'suspend fun <T : Any> Bar.find(a: String, vararg rest: Int): List<T>? {}', { '@param T', '@param a', '@param rest', '@return' } },
  { 'kotlin', 'fun x(): Unit {}', {} },
  { 'kotlin', 'class Foo<T>(val a: Int, b: String) {}', { '@param T', '@param a', '@param b' } },
}
for _, c in ipairs(cases) do
  local ok, got = pcall(require('custom.snippets.' .. c[1]).tags_for, c[2])
  if not ok then
    fail(('snippet %s %q: %s'):format(c[1], c[2], got))
  elseif not vim.deep_equal(got, c[3]) then
    fail(('snippet %s %q: expected %s, got %s'):format(c[1], c[2], vim.inspect(c[3]), vim.inspect(got)))
  end
end

-- 4. <CR> after `/**` expands in a Java buffer and leaves other lines alone.
vim.cmd 'enew!'
vim.bo.filetype = 'java'
vim.api.nvim_buf_set_lines(0, 0, -1, false, { '/**', 'void run(int a) {', '}' })
-- the cursor sits past the last character only in insert mode
vim.cmd 'startinsert!'
vim.wait(50)
local docblock = require 'custom.snippets.docblock'
if not docblock.expand_on_enter() then fail 'expand_on_enter did not expand a lone /**' end
local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
if not text:find('@param a', 1, true) then fail('expansion lacks @param a:\n' .. text) end
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'int x = 1;' })
vim.cmd 'startinsert!'
vim.wait(50)
if docblock.expand_on_enter() then fail 'expand_on_enter expanded a normal line' end

if #failures > 0 then
  io.stderr:write('FAILED:\n  ' .. table.concat(failures, '\n  ') .. '\n')
  vim.cmd 'cquit 1'
end
print 'check.sh: all good'
vim.cmd 'qa!'
