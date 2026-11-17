-- Lua LSP setup for your Neovim config, runtime and plugins: completion, annotations and signatures of Neovim APIs.
require('lazydev').setup {
  library = {
    -- Load luvit types when the `vim.uv` word is found
    { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
  },
}
