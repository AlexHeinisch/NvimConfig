return { -- Autoformat
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
        {
            '<leader>f',
            function()
                require('conform').format { async = true, lsp_format = 'fallback' }
            end,
            mode = '',
            desc = '[F]ormat buffer',
        },
    },
    opts = {
        notify_on_error = false,
        formatters_by_ft = {
            lua = { 'stylua' },
            java = { lsp_format = 'prefer' },
            rust = { 'rustfmt' },
            -- Conform can also run multiple formatters sequentially
            -- python = { "isort", "black" },
            --
            -- You can use 'stop_after_first' to run the first available formatter from the list
            -- javascript = { "prettierd", "prettier", stop_after_first = true },
        },
        -- Configure formatters to respect buffer settings
        formatters = {
            stylua = {
                prepend_args = function(self, ctx)
                    -- Respect buffer indentation settings detected by guess-indent
                    local indent_type = vim.bo[ctx.buf].expandtab and 'Spaces' or 'Tabs'
                    local indent_width = vim.bo[ctx.buf].shiftwidth
                    return {
                        '--indent-type',
                        indent_type,
                        '--indent-width',
                        tostring(indent_width),
                    }
                end,
            },
            rustfmt = {
                prepend_args = function(self, ctx)
                    -- Respect buffer indentation settings detected by guess-indent
                    local args = {}
                    if vim.bo[ctx.buf].expandtab then
                        table.insert(args, '--config')
                        table.insert(args, 'hard_tabs=false')
                        table.insert(args, '--config')
                        table.insert(args, 'tab_spaces=' .. tostring(vim.bo[ctx.buf].shiftwidth))
                    else
                        table.insert(args, '--config')
                        table.insert(args, 'hard_tabs=true')
                    end
                    return args
                end,
            },
        },
    },
}
