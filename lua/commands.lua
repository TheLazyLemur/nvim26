vim.api.nvim_create_user_command("Format", function(args)
    local range = nil
    if args.count ~= -1 then
        local end_line = vim.api.nvim_buf_get_lines(0, args.line2 - 1, args.line2, true)[1]
        range = {
            start = { args.line1, 0 },
            ["end"] = { args.line2, end_line:len() },
        }
    end
    require("conform").format({ async = false, lsp_format = "fallback", range = range })
end, { range = true })

vim.api.nvim_create_user_command("Lint", function(_)
    require("lint").try_lint()
end, { range = false })

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

augroup('YankHighlight', { clear = true })
autocmd('TextYankPost', {
    group = 'YankHighlight',
    callback = function()
        vim.highlight.on_yank()
    end,
})

augroup('RestoreCursor', { clear = true })
autocmd('BufReadPost', {
    group = 'RestoreCursor',
    callback = function()
        local mark = vim.api.nvim_buf_get_mark(0, '"')
        local lcount = vim.api.nvim_buf_line_count(0)
        if mark[1] > 0 and mark[1] <= lcount then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
    end,
})
