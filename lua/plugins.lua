local plugins = {
    {
        src = "nvim-lua/plenary.nvim",
    },
    {
        src = "nvim-neotest/nvim-nio",
    },
    {
        src = "stevearc/oil.nvim",
        config = function()
            require("oil").setup()
        end,
    },
    {
        src = "echasnovski/mini.icons",
        config = function()
            require("mini.icons").setup()
        end,
    },
    {
        src = "echasnovski/mini.diff",
        config = function()
            require('mini.diff').setup({
                view = {
                    style = 'sign',
                    signs = { add = '+', change = '~', delete = '-' },
                },
                mappings = {
                    apply = 'gh',
                    reset = 'gH',
                    textobject = 'gh',
                    goto_first = '[H',
                    goto_prev = '[h',
                    goto_next = ']h',
                    goto_last = ']H',
                },
            })
        end,
    },
    {
        src = "catppuccin/nvim",
        config = function()
            require("catppuccin").setup({
                flavour = "mocha",
            })
            vim.cmd.colorscheme("catppuccin")
        end,
    },
    {
        src = "lewis6991/gitsigns.nvim",
    },
    {
        src = "mason-org/mason.nvim",
        config = function()
            require("mason").setup({
                registries = {
                    "github:crashdummyy/mason-registry",
                    "github:mason-org/mason-registry",
                },
            })
        end,
    },
    {
        src = "seblyng/roslyn.nvim",
        config = function()
            require("roslyn").setup({})
        end,
    },
    {
        src = "neovim/nvim-lspconfig",
        config = function()
            vim.lsp.config('gopls', {
                cmd_env = { CGO_ENABLED = "1" },
                root_markers = { "go.work", "go.mod", ".git" },
                capabilities = {
                    workspace = {
                        didChangeWatchedFiles = {
                            dynamicRegistration = false,
                        },
                    },
                },
                settings = {
                    gopls = {
                        expandWorkspaceToModule = true,
                        experimentalPostfixCompletions = true,
                    },
                },
            })
            vim.lsp.enable('gopls')
            vim.lsp.config('lua_ls', {
                settings = {
                    Lua = {
                        runtime = {
                            version = "LuaJIT",
                        },
                        diagnostics = {
                            globals = { "vim" },
                        },
                        workspace = {
                            library = vim.api.nvim_get_runtime_file("", true),
                            checkThirdParty = false,
                        },
                        telemetry = {
                            enable = false,
                        },
                    },
                },
            })
            vim.lsp.enable('lua_ls')
            vim.lsp.config('ts_ls', {})
            vim.lsp.enable('ts_ls')
            vim.lsp.config('clangd', {})
            vim.lsp.enable('clangd')
            vim.lsp.config('ols', {})
            vim.lsp.enable('ols')
            vim.lsp.config('templ', {})
            vim.lsp.enable('templ')
            vim.lsp.config('svelte', {})
            vim.lsp.enable('svelte')
            vim.lsp.config('jdtls', {
                root_markers = { "pom.xml", "build.gradle", ".git" },
            })
            vim.lsp.enable('jdtls')
        end
    },
    {
        src = "mfussenegger/nvim-lint",
        config = function()
            require("lint").linters_by_ft = {
                go = { "revive" },
                typescript = { "eslint" },
                typescriptreact = { "eslint" },
                javascript = { "eslint" },
                javascriptreact = { "eslint" },
            }
        end,
    },
    {
        src = "stevearc/conform.nvim",
        config = function()
            require("conform").setup({
                formatters_by_ft = {
                    go = { "gofumpt", "goimports", "goimports-reviser", "golines" },
                    typescript = { "prettier" },
                    typescriptreact = { "prettier" },
                    javascript = { "prettier" },
                    javascriptreact = { "prettier" },
                    json = { "prettier" },
                    yaml = { "prettier" },
                    markdown = { "prettier" },
                },
            })
        end,
    },
    {
        src = "saghen/blink.cmp",
        config = function()
            -- Build blink.cmp with cargo
            local build_dir = vim.fn.stdpath("data") .. "/pack/deps/start/blink.cmp"
            if vim.fn.isdirectory(build_dir) == 1 then
                vim.api.nvim_create_autocmd("User", {
                    pattern = "VeryLazy",
                    once = true,
                    callback = function()
                        local handle = vim.system({ "cargo", "build", "--release" }, {
                            cwd = build_dir,
                            text = true,
                        }, function(result)
                            if result.code == 0 then
                                vim.notify("blink.cmp built successfully", vim.log.levels.INFO)
                            else
                                vim.notify("blink.cmp build failed: " .. (result.stderr or ""), vim.log.levels.ERROR)
                            end
                        end)
                    end,
                })
            end

            require("blink.cmp").setup({
                sources = {
                    default = { "lsp", "path", "snippets", "buffer" },
                },
                completion = {
                    menu = {
                        border = "rounded",
                        winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
                    },
                    documentation = {
                        auto_show = true,
                        window = {
                            border = "rounded",
                            winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
                        },
                    },
                },
                signature = {
                    enabled = true,
                    window = {
                        border = "rounded",
                        winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
                    },
                },
            })
        end,
    },
    {
        src = "folke/snacks.nvim",
        config = function()
            require("snacks").setup({
                picker = { enabled = true },
                explorer = { enabled = true },
            })

            -- Make snacks picker transparent
            vim.api.nvim_create_autocmd("FileType", {
                pattern = { "snacks_picker", "snacks_picker_input", "snacks_picker_list" },
                callback = function()
                    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "NONE" })
                    vim.api.nvim_set_hl(0, "FloatBorder", { bg = "NONE" })
                end,
            })
        end,
    },
    {
        src = "nvim-treesitter/nvim-treesitter",
        version = "main",
        config = function()
            local ok_configs, configs = pcall(require, "nvim-treesitter.configs")
            if ok_configs then
                configs.setup({
                    ---@diagnostic disable-next-line: missing-fields
                    ensure_installed = { "lua", "vim", "vimdoc", "query", "markdown", "markdown_inline", "go", "typescript", "tsx", "javascript", "c", "odin", "templ", "java", "c_sharp", "razor" },
                    highlight = { enable = true },
                    indent = { enable = true },
					sync_install = true,
                })
            end

            vim.api.nvim_create_autocmd("User", {
                pattern = "VeryLazy",
                once = true,
                callback = function()
                    local ok_installer, installer = pcall(require, "nvim-treesitter.install")
                    if ok_installer then
                        installer.update({ with_sync = false })()
                    end
                end,
            })
            vim.api.nvim_create_autocmd('FileType', {
                pattern = { 'go', 'markdown', 'lua', 'javascript', 'c', 'odin', 'svelte', 'java', 'cs', 'razor' },
                callback = function() vim.treesitter.start() end,
            })
        end,
    },
    {
        src = 'MeanderingProgrammer/render-markdown.nvim',
        config = function()
            require("render-markdown").setup()
        end
    },
    {
        src = "fredrikaverpil/neotest-golang",
    },
    {
        src = "folke/trouble.nvim",
        config = function()
            require("trouble").setup({
                position = "bottom",
                height = 10,
                width = 50,
                mode = "workspace_diagnostics",
                fold_open = "v",
                fold_closed = ">",
                group = true,
                padding = true,
                cycle_results = true,
                action_keys = {
                    close = "q",
                    cancel = "<esc>",
                    refresh = "r",
                    jump = { "<cr>", "<tab>", "<2-leftmouse>" },
                    open_split = { "<c-x>" },
                    open_vsplit = { "<c-v>" },
                    open_tab = { "<c-t>" },
                    jump_close = { "o" },
                    toggle_mode = "m",
                    switch_severity = "s",
                    toggle_preview = "P",
                    hover = "K",
                    preview = "p",
                    open_code_action = "a",
                    close_folds = { "zM", "zm" },
                    open_folds = { "zR", "zr" },
                    toggle_fold = { "zA", "za" },
                    previous = "k",
                    next = "j",
                    help = "?",
                },
                multiline = true,
                indent_lines = true,
                win_config = { border = "single" },
                auto_open = false,
                auto_close = false,
                auto_preview = true,
                auto_fold = false,
                auto_jump = { "lsp_definitions" },
                include_declaration = {
                    "lsp_references",
                    "lsp_implementations",
                    "lsp_definitions",
                },
                signs = {
                    error = "",
                    warning = "",
                    hint = "",
                    information = "",
                    other = "",
                },
                use_diagnostic_signs = false,
            })
        end,
    },
    {
        src = "nvim-neotest/neotest",
        config = function()
            local config = {
                runner = "gotestsum", -- Optional, but recommended
            }
            require("neotest").setup({
                adapters = {
                    require("neotest-golang")(config),
                },
            })
        end,
    },
	{
		src = "BlinkResearchLabs/blink-edit.nvim",
		config = function()
			require("blink-edit").setup({
				llm = {
					provider = "kimi",
					backend = "openai",
					url = "http://0.0.0.0:4000",
					model = "anthropic/kimi-for-coding",
					timeout_ms = 10000,
				},
			})
		end,
	},
	{
		src = "TheLazyLemur/neogent.nvim",
	},
}

for _, plugin in ipairs(plugins) do
    local default_prefix = "https://github.com/"
    plugin.src = default_prefix .. plugin.src
    pcall(vim.pack.add, { plugin })
    local config_func = plugin.config or function() end
    pcall(config_func)
end
