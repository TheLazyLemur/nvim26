# Code Map

This file contains an overview of the codebase structure and key components.

## File Structure

- `init.lua` - Neovim configuration entry point that loads all modules
- `lua/commands.lua` - Custom user commands and autocommands
- `lua/floatterm.lua` - Floating terminal implementation
- `lua/keymaps.lua` - Key mappings configuration
- `lua/options.lua` - Neovim options configuration with custom statusline
- `lua/plugins.lua` - Plugin configurations and setup
- `CLAUDE.md` - Project architecture and development guide for Claude Code

## Key Components

### Root Configuration (`init.lua`)

#### Structure
Simple module loader that requires all core modules in order:
- options
- plugins  
- keymaps
- commands
- floatterm

#### Functions
- None (module loading only)

### Commands (`lua/commands.lua`)

#### Global Variables
- `augroup` - Reference to vim.api.nvim_create_augroup
- `autocmd` - Reference to vim.api.nvim_create_autocmd

#### User Commands
- `:Format` - Format code using conform.nvim with optional range support
- `:Lint` - Run linting using nvim-lint

#### Autocommands
- `YankHighlight` - Highlights yanked text briefly after yanking

### Floating Terminal (`lua/floatterm.lua`)

#### Module Variables
- `M` - Module table for exports
- `config` - Configuration table with width/height ratios and border style
- `state` - State table tracking window and buffer handles

#### Functions
- `get_window_config()` - Calculate floating window configuration → table
- `M.toggle()` - Toggle floating terminal window → nil

### Key Mappings (`lua/keymaps.lua`)

#### Key Categories
- **Claude Code**: `<leader>cc` - Open Claude Code
- **File Navigation**: `-` - Oil file manager
- **LSP**: `gd`, `gr`, `gi`, `K`, `<leader>rn`, `<leader>ca`
- **Diagnostics**: `<leader>e`, `<leader>xx`, `<leader>xw`, `<leader>xd`
- **Formatting**: `<leader>f` - Format current buffer or selection
- **Pickers**: `<leader>sf` (files), `<leader>sg` (grep), `<leader><leader>.` (buffers)
- **Window Navigation**: `<C-h/j/k/l>` for movement
- **Window Resize**: `<C-Arrow>` keys for resizing
- **Text Movement**: `J/K` in visual mode to move lines
- **Search**: `n/N` with centering, `<Esc>` to clear highlights
- **Terminal**: `<leader>tt`, `<C-\>` - Toggle floating terminal

#### Functions
- None (keymap definitions only)

### Options (`lua/options.lua`)

#### Global Variables
- `vim.g.mapleader` - Leader key set to space
- Various vim.o options for editor configuration

#### Functions
- `_G.my_statusline()` - Custom statusline function that shows mode, filename, filetype, git branch, line:column, and time → string

### Plugin Configuration (`lua/plugins.lua`)

#### Plugin List
- **nvim-acp** - ACP (Anthropic Claude Protocol) chat integration
- **tokyonight.nvim** - Tokyo Night colorscheme with custom WinSeparator highlighting
- **plenary.nvim** - Lua utility functions
- **nvim-nio** - Async I/O library
- **claudecode.nvim** - Claude Code integration
- **oil.nvim** - File manager
- **mini.icons** - Icon provider
- **gitsigns.nvim** - Git integration
- **mason.nvim** - LSP/tool installer
- **nvim-lspconfig** - LSP configuration (Go, Lua, TypeScript)
- **nvim-lint** - Linting (Go with revive, TypeScript/JavaScript with eslint)
- **conform.nvim** - Formatting (Go with multiple formatters, TypeScript/JavaScript with prettier)
- **blink.cmp** - Completion engine
- **snacks.nvim** - Picker and explorer utilities
- **nvim-treesitter** - Syntax highlighting (includes TypeScript, JSX, TSX support)
- **render-markdown.nvim** - Markdown rendering
- **neotest-golang** - Go testing integration
- **trouble.nvim** - Diagnostics UI
- **neotest** - Testing framework

#### Structure
- `plugins` - Table of plugin definitions with src and config
- Automatic loading logic that adds GitHub prefix and loads each plugin

#### Functions
- None (configuration only)

## Architecture Notes

### Plugin Management
Uses Neovim's built-in package management (`vim.pack.add`) rather than external plugin managers. Each plugin is loaded with error handling via `pcall`.

### LSP Configuration
- **Go**: Uses gopls with default configuration
- **Lua**: Uses lua_ls with Neovim-specific settings including vim globals and runtime configuration

### Formatting & Linting
- **Go formatting**: Uses multiple formatters in sequence (gofumpt, goimports, goimports-reviser, golines)
- **Go linting**: Uses revive linter
- **TypeScript/JavaScript formatting**: Uses prettier for consistent code style
- **TypeScript/JavaScript linting**: Uses eslint for code quality and error detection
- **Additional formatting**: Prettier also handles JSON, YAML, and Markdown files
- **Range formatting**: Supported via `:Format` command

### UI Components
- **Floating terminal**: Configurable size and border styling
- **Custom statusline**: Shows comprehensive information including git branch
- **Completion**: Blink.cmp with LSP, path, snippets, and buffer sources
- **Diagnostics**: Trouble.nvim for enhanced diagnostic display