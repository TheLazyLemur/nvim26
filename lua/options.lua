vim.g.mapleader = " "

vim.filetype.add({
    extension = {
        templ = "templ",
    },
})

vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.hlsearch = true
vim.o.incsearch = true
vim.o.grepprg = "rg --vimgrep"

vim.o.cursorline = true
vim.o.number = true
vim.o.wrap = false
vim.o.tabstop = 4
vim.o.laststatus = 3

vim.o.swapfile = false
vim.o.undofile = true
vim.o.writebackup = false

vim.o.termguicolors = true
vim.o.pumheight = 10
vim.o.showmode = false
vim.o.ruler = false
vim.o.scrolloff = 8
vim.o.sidescrolloff = 8
vim.o.signcolumn = "yes"

vim.o.splitright = true
vim.o.splitbelow = true
vim.o.equalalways = false

vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.o.foldlevelstart = 99
vim.o.foldenable = true

if vim.g.neovide then
    -- Font
    vim.o.guifont = "ZedMono Nerd Font:h20:w1"
    vim.opt.linespace = 5
    vim.g.neovide_text_gamma = 0.1
    vim.g.neovide_text_contrast = 0.3
    -- Transparency & Blur
    vim.g.neovide_opacity = 0.92
    vim.g.neovide_window_blurred = true
    -- Padding
    vim.g.neovide_padding_top = 6
    vim.g.neovide_padding_bottom = 6
    vim.g.neovide_padding_right = 8
    vim.g.neovide_padding_left = 8
    -- Cursor candy
    vim.g.neovide_cursor_animation_length = 0.1
    vim.g.neovide_cursor_trail_size = 0.7
    vim.g.neovide_cursor_vfx_mode = "railgun"
    -- Smooth scrolling
    vim.g.neovide_scroll_animation_length = 0.3
end

function _G.my_statusline()
    local mode = vim.fn.mode()
    local filename = vim.fn.expand("%:t") ~= "" and vim.fn.expand("%:t") or "[No Name]"
    local filetype = vim.bo.filetype ~= "" and vim.bo.filetype or "none"
    local lineinfo = string.format("%3d:%-2d", vim.fn.line("."), vim.fn.col("."))

    local branch = ""
    local git_dir = vim.fn.finddir(".git", ".;") -- finds .git in cwd or parents
    if git_dir ~= "" then
        local b = vim.fn.systemlist("git branch --show-current 2>/dev/null")[1]
        if b and #b > 0 then
            branch = "  " .. b
        end
    end

    return table.concat({
        " ", mode, " | ",
        filename, " [", filetype, "]",
        branch,
        " %=",
        lineinfo, "  ", os.date("%I:%M %p")
    })
end

vim.o.statusline = "%!v:lua.my_statusline()"
