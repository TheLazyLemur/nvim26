local keymap = vim.keymap.set

if vim.g.neovide then
    keymap('n', '<D-v>', '"+P')
    keymap('i', '<D-v>', '<C-r>+')
    keymap('c', '<D-v>', '<C-r>+')
    keymap('v', '<D-v>', '"+P')


    vim.g.neovide_scale_factor = 1.0

    local change_scale_factor = function(delta)
        vim.g.neovide_scale_factor = vim.g.neovide_scale_factor * delta
    end
    keymap("n", "<C-=>", function()
        change_scale_factor(1.10)
    end)
    keymap("n", "<C-->", function()
        change_scale_factor(1 / 1.10)
    end)
end

keymap("n", "<leader>ba", require("modules/jumper").add_jump_point)
keymap("n", "<leader>bo", require("modules/jumper").jump_to)
keymap("n", "<leader>bd", require("modules/jumper").delete_jump_point)

keymap("n", "<leader>cc", "<cmd>ClaudeCode<cr>")
keymap("n", "<leader>ac", "<cmd>Neogent<cr>", { desc = "Toggle Neogent" })
keymap("n", "-", "<cmd>Oil<cr>")
keymap("n", "<leader>n", require("modules/filetree").toggle, { desc = "Toggle file tree" })

keymap("n", "<leader>gs", "<cmd>Git<cr>", { desc = "Git status" })
keymap("n", "<leader>gb", "<cmd>Git blame<cr>", { desc = "Git blame" })

keymap("n", "<leader>fc", "<cmd>foldclose<cr>", { desc = "Fold Close" })
keymap("n", "<leader>fo", "<cmd>foldopen<cr>", { desc = "Fold Open" })

keymap("n", "gd", vim.lsp.buf.definition)
keymap("n", "gr", vim.lsp.buf.references)
keymap("n", "gi", vim.lsp.buf.implementation)
keymap("n", "K", vim.lsp.buf.hover, { desc = "Hover documentation" })
keymap("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })
keymap("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })
keymap("v", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action (visual)" })
keymap("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show diagnostic float" })
keymap("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Toggle trouble diagnostics list" })
keymap("n", "<leader>xw", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
    { desc = "Workspace diagnostics list" })
keymap("n", "<leader>xd", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
    { desc = "Document diagnostics list" })

keymap({ "n", "v" }, "<leader>f", "<cmd>Format<cr>")
keymap("n", "<leader>sf", Snacks.picker.files)
keymap("n", "<leader>sg", Snacks.picker.grep)
keymap("n", "<leader><leader>", Snacks.picker.buffers)

keymap("n", "<C-h>", "<C-w>h", { desc = "Navigate left" })
keymap("n", "<C-j>", "<C-w>j", { desc = "Navigate down" })
keymap("n", "<C-k>", "<C-w>k", { desc = "Navigate up" })
keymap("n", "<C-l>", "<C-w>l", { desc = "Navigate right" })

keymap("t", "<C-h>", "<cmd>wincmd h<cr>", { desc = "Navigate left" })
keymap("t", "<C-j>", "<cmd>wincmd j<cr>", { desc = "Navigate down" })
keymap("t", "<C-k>", "<cmd>wincmd k<cr>", { desc = "Navigate up" })
keymap("t", "<C-l>", "<cmd>wincmd l<cr>", { desc = "Navigate right" })

keymap("n", "<C-Up>", ":resize +2<CR>", { desc = "Increase height" })
keymap("n", "<C-Down>", ":resize -2<CR>", { desc = "Decrease height" })
keymap("n", "<C-Left>", ":vertical resize -2<CR>", { desc = "Decrease width" })
keymap("n", "<C-Right>", ":vertical resize +2<CR>", { desc = "Increase width" })

keymap("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move line down" })
keymap("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move line up" })

keymap("n", "n", "nzzzv", { desc = "Next search result centered" })
keymap("n", "N", "Nzzzv", { desc = "Previous search result centered" })
keymap("n", "<C-d>", "<C-d>zz", { desc = "Half page down centered" })
keymap("n", "<C-u>", "<C-u>zz", { desc = "Half page up centered" })

keymap("x", "<leader>p", '"_dP', { desc = "Paste without yanking" })

keymap("n", "<Esc>", ":noh<CR>", { desc = "Clear search highlight" })

keymap({ "n", "t" }, "<leader>tt", require("floatterm").select_terminal_menu,
    { desc = "Toggle floating terminal" })
keymap({ "n", "t" }, "<leader>tn", require("floatterm").add_named_terminal, { desc = "Toggle floating terminal" })

keymap('t', '<Esc>', [[<C-\><C-n>]], { desc = 'Switch to normal mode in terminal' })

-- AI Operator (g=)
require("modules.ai_operator").setup()
