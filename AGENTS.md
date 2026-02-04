# AGENTS.md - Neovim Configuration Guide

This is a personal Neovim configuration using **Neovim's built-in package manager** (`vim.pack`). It is not a plugin development repository.

## Project Overview

- **Type**: Personal Neovim configuration
- **Plugin Manager**: Native `vim.pack.add()` (Neovim 0.10+)
- **Languages**: Go, TypeScript/JavaScript, Lua, C/C++, Odin, Templ, Svelte, Java, C#
- **AI Integration**: Claude Code, CodeCompanion, OpenCode

## File Structure

```
~/.config/nvim2026/
├── init.lua                    -- Entry point, loads all modules
├── lua/
│   ├── options.lua             -- Vim options, statusline, filetype associations
│   ├── plugins.lua             -- Plugin definitions using vim.pack.add()
│   ├── keymaps.lua             -- All key mappings
│   ├── commands.lua            -- User commands (:Format, :Lint) and autocommands
│   ├── floatterm.lua           -- Floating terminal implementation
│   ├── ai.lua                  -- AI plugin setup (codecompanion, claudecode, opencode)
│   └── modules/
│       ├── inline_completion.lua  -- Ghost text completion via Claude CLI
│       ├── jumper.lua          -- Jump point management (arglist wrapper)
│       ├── filetree.lua        -- Custom file tree sidebar
│       └── colorscheme.lua     -- "Oxidized Copper" custom colorscheme
├── nvim-pack-lock.json         -- Plugin lock file
├── codemap.md                  -- Codebase documentation
└── CLAUDE.md                   -- CodeCompanion instructions
```

## Essential Commands

Since this is a Neovim configuration, there are no traditional build/test commands. Changes take effect on Neovim restart or by reloading the config.

### Reloading Configuration
```vim
:source ~/.config/nvim2026/init.lua    -- Reload entire config
:luafile lua/plugins.lua               -- Reload specific module
```

### Managing Plugins
Plugins are managed via `nvim-pack-lock.json`. The lock file pins plugin versions.

- Plugins auto-install on first Neovim start
- To update: Edit `nvim-pack-lock.json` with new commit hashes
- To add: Add entry to `lua/plugins.lua` and lock file

### LSP Commands
```vim
:LspInfo                               -- Check LSP status
:LspRestart                            -- Restart LSP clients
:Mason                                 -- Open Mason installer
```

### Custom Commands
```vim
:Format                                -- Format buffer/selection (conform.nvim)
:Lint                                  -- Run linter (nvim-lint)
:ClaudeCode                            -- Open Claude Code panel
```

## Code Patterns & Conventions

### Module Pattern
All Lua modules follow this pattern:
```lua
local M = {}

M.config = {                          -- Configuration table
    option = "value",
}

local state = {}                      -- Private state

function M.setup(opts)                -- Public setup function
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

function M.public_function()          -- Public API
    -- implementation
end

local function private_function()     -- Private function
    -- implementation
end

return M
```

### Error Handling
Always use `pcall()` for plugin operations that might fail:
```lua
local ok, result = pcall(require, "module")
if not ok then
    vim.notify("Failed to load: " .. result, vim.log.levels.ERROR)
    return
end
```

### Plugin Loading (vim.pack)
Plugins are defined in `lua/plugins.lua` with this structure:
```lua
local plugins = {
    {
        src = "owner/repo",           -- GitHub repo (prefix added automatically)
        config = function()
            require("plugin").setup({})
        end,
    },
}

-- Auto-prefix and load with error handling
for _, plugin in ipairs(plugins) do
    plugin.src = "https://github.com/" .. plugin.src
    pcall(vim.pack.add, { plugin })
    pcall(plugin.config or function() end)
end
```

### LSP Configuration (Neovim 0.11+ API)
Uses the new `vim.lsp.config()` and `vim.lsp.enable()` API:
```lua
vim.lsp.config('server_name', {
    settings = { ... },
    root_markers = { ... },
})
vim.lsp.enable('server_name')
```

### Keymap Conventions
```lua
local keymap = vim.keymap.set

-- Always use description for which-key visibility
keymap("n", "<leader>key", action, { desc = "Human readable description" })

-- Leader key is SPACE (set in options.lua)
-- Common prefixes:
-- <leader>s  = search/pickers
-- <leader>x  = diagnostics/trouble
-- <leader>g  = git
-- <leader>f  = format
-- <leader>b  = buffers/jump points
-- <leader>tt = terminal
```

### Autocommand Pattern
```lua
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

augroup('GroupName', { clear = true })
autocmd('EventName', {
    group = 'GroupName',
    callback = function()
        -- handler
    end,
})
```

## Testing Approach

There are no automated tests for this configuration. Testing is manual:

1. **Start Neovim**: Check for errors on startup
2. **Test plugins**: Verify key plugins load (`:checkhealth`)
3. **Test LSP**: Open file of each language, verify LSP attaches (`:LspInfo`)
4. **Test keymaps**: Verify custom keymaps work
5. **Test AI integration**: Open Claude Code or CodeCompanion

## Language-Specific Tooling

### Go
- **LSP**: gopls
- **Lint**: revive
- **Format**: gofumpt → goimports → goimports-reviser → golines
- **Test**: neotest-golang

### TypeScript/JavaScript
- **LSP**: ts_ls
- **Lint**: eslint
- **Format**: prettier

### Lua
- **LSP**: lua_ls
- **Settings**: Configured for Neovim plugin development (vim globals, LuaJIT runtime)

## AI Integration Details

### CodeCompanion (olimorris/codecompanion.nvim)
- Custom tools defined in `ai.lua`: `plan`, `task`, `get_time`
- Tools use `claude` CLI with different permission levels
- Adapters: GLM, MiniMax (Anthropic-compatible APIs)

### Inline Completion (modules/inline_completion.lua)
- Ghost text completion using Claude CLI
- Triggers on `TextChangedI` with debounce
- Accept with `<Tab>`, cancel with `<Esc>`
- Uses JSON schema for structured output

### claudecode.nvim & opencode.nvim
- Additional AI assistant integrations
- Configured in `ai.lua` setup function

## Important Gotchas

### Plugin Manager is Built-in
Do NOT use lazy.nvim, packer, or other plugin managers. This config uses Neovim's native `vim.pack.add()` introduced in Neovim 0.10.

### Lock File Required
The `nvim-pack-lock.json` file pins exact plugin versions. Without it, plugins may auto-update unexpectedly.

### LSP API Version
Uses Neovim 0.11+ LSP API (`vim.lsp.config`, `vim.lsp.enable`). Will not work on older Neovim versions.

### External Dependencies
Several features require CLI tools installed separately:
- `claude` - For AI features (inline completion, plan/task tools)
- `cargo` - For building blink.cmp
- `rg` (ripgrep) - For grep functionality
- Go toolchain - For Go development
- Node.js - For TypeScript/JavaScript LSP

### Custom Filetype
`templ` files are registered in `options.lua` for Templ template language support.

### Terminal Navigation
Terminal mode uses `<C-\><C-n>` to exit to normal mode. Window navigation works from terminal mode via `<C-h/j/k/l>` mapped to `<cmd>wincmd h/j/k/l<cr>`.

### Floating Terminal State
Terminals are stored in a state table in `floatterm.lua`. They persist across toggles but are not saved between Neovim sessions.

## Modifying the Configuration

### Adding a Plugin
1. Add entry to `plugins` table in `lua/plugins.lua`
2. Add entry to `nvim-pack-lock.json` with commit hash
3. Restart Neovim

### Adding a Keymap
Add to `lua/keymaps.lua` following existing patterns. Always include a `desc` for which-key.

### Adding a Command
Add to `lua/commands.lua` using `vim.api.nvim_create_user_command()`.

### Adding a Language
1. Add LSP config in `lua/plugins.lua` under `nvim-lspconfig`
2. Add treesitter parser to `ensure_installed`
3. Add formatters to `conform.nvim` config if needed
4. Add linters to `nvim-lint` config if needed

## Code Style

- **Indentation**: 4 spaces (see `vim.o.tabstop = 4`)
- **Quotes**: Double quotes for strings in Lua
- **Semicolons**: Not used
- **Line length**: No enforced limit
- **Comments**: `--` for single line, `--[[ ]]` for block
- **Variable naming**: `snake_case` for locals, `M` for module tables
