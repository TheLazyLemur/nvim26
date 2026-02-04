# AI Operator Context

This is the default context file for the g= AI operator in Neovim.

## Project Guidelines

- Write idiomatic, minimal code
- Prefer Lua for Neovim configuration
- Follow existing patterns in the codebase
- Keep implementations simple and focused

## Code Style

- Use 4 spaces for indentation in Lua
- Prefer local functions over module-level where appropriate
- Add type annotations with EmmyLua comments for public APIs
- Keep functions small and single-purpose

## Neovim Conventions

- Use `vim.api.nvim_*` functions for buffer/window manipulation
- Prefer `vim.keymap.set` over `vim.api.nvim_set_keymap`
- Use namespaced autocommands with `vim.api.nvim_create_autocmd`
- Handle errors gracefully with `pcall` for external dependencies
