-- "Oxidized Copper" - Brutalist industrial colorscheme
-- Dark:  charcoal base, oxidized teal patina, warm amber, rust accents
-- Light: sun-bleached paper, aged copper tones, deep patina

local M = {}

local colors_dark = {
  bg = "#1a1d1f",           -- warm charcoal, hint of industrial green
  fg = "#c8c5be",           -- aged paper/bone white
  accent = "#5f9e8f",       -- oxidized copper patina (teal-green)
  string = "#d4a054",       -- warm amber/brass

  -- Derived colors
  bg_light = "#252a2c",     -- slightly lifted charcoal
  fg_dim = "#6b7278",       -- weathered steel grey
  accent_dim = "#3d5550",   -- deep patina shadow
  rust = "#b86f4e",         -- rust accent for warnings
}

local colors_light = {
  bg = "#f5f1e8",           -- sun-bleached linen
  fg = "#3a3633",           -- aged ink/iron gall
  accent = "#2d7064",       -- deep verdigris
  string = "#a67424",       -- aged brass/amber

  -- Derived colors
  bg_light = "#e8e2d6",     -- shadowed parchment
  fg_dim = "#8a847a",       -- faded graphite
  accent_dim = "#c4d4d0",   -- pale patina wash
  rust = "#9e5a38",         -- terracotta rust
}

local colors_machinery = {
  bg = "#0f0e0d",           -- coal black/soot
  fg = "#d4cfc6",           -- steam/ash white
  accent = "#c67b4e",       -- hot copper pipes
  string = "#e8a84c",       -- brass fittings

  -- Derived colors
  bg_light = "#1c1918",     -- warm coal shadow
  fg_dim = "#6d6560",       -- cooled ash
  accent_dim = "#4a3028",   -- oxidized iron
  rust = "#b84a32",         -- ember red
}

local colors = colors_dark

local function highlight(group, opts)
  local cmd = "highlight " .. group
  if opts.fg then cmd = cmd .. " guifg=" .. opts.fg end
  if opts.bg then cmd = cmd .. " guibg=" .. opts.bg end
  if opts.style then cmd = cmd .. " gui=" .. opts.style end
  vim.cmd(cmd)
end

function M.setup(variant)
  variant = variant or "dark"
  if variant == "light" then
    colors = colors_light
  elseif variant == "machinery" then
    colors = colors_machinery
  else
    colors = colors_dark
  end

  vim.cmd("highlight clear")
  if vim.fn.exists("syntax_on") then
    vim.cmd("syntax reset")
  end
  vim.o.background = variant == "light" and "light" or "dark"
  vim.g.colors_name = "oxidized"

  -- Editor UI
  highlight("Normal", { fg = colors.fg, bg = colors.bg })
  highlight("NormalFloat", { fg = colors.fg, bg = colors.bg_light })
  highlight("LineNr", { fg = colors.fg_dim })
  highlight("CursorLine", { bg = colors.bg_light })
  highlight("CursorLineNr", { fg = colors.accent })
  highlight("Cursor", { fg = colors.bg, bg = colors.accent })
  highlight("TermCursor", { fg = colors.bg, bg = colors.accent })
  highlight("Visual", { bg = colors.accent_dim, style = "bold" })
  highlight("Search", { fg = colors.bg, bg = colors.accent })
  highlight("IncSearch", { fg = colors.bg, bg = colors.accent })
  highlight("MatchParen", { bg = colors.accent_dim, style = "bold" })
  highlight("StatusLine", { fg = colors.bg, bg = colors.accent })
  highlight("StatusLineNC", { fg = colors.fg_dim, bg = colors.bg_light })
  highlight("VertSplit", { fg = colors.bg_light })
  highlight("TabLine", { fg = colors.fg_dim, bg = colors.bg_light })
  highlight("TabLineSel", { fg = colors.bg, bg = colors.accent })
  highlight("TabLineFill", { bg = colors.bg })
  highlight("Pmenu", { fg = colors.fg, bg = colors.bg_light })
  highlight("PmenuSel", { fg = colors.bg, bg = colors.accent })
  highlight("SignColumn", { bg = colors.bg })
  highlight("ColorColumn", { bg = colors.bg_light })
  highlight("Folded", { fg = colors.fg_dim, bg = colors.bg_light })
  highlight("EndOfBuffer", { fg = colors.bg })

  -- Syntax highlighting
  highlight("Comment", { fg = colors.fg_dim })
  highlight("Constant", { fg = colors.accent })
  highlight("String", { fg = colors.string })
  highlight("Character", { fg = colors.string })
  highlight("Number", { fg = colors.accent })
  highlight("Boolean", { fg = colors.accent })
  highlight("Float", { fg = colors.accent })

  highlight("Identifier", { fg = colors.fg })
  highlight("Function", { fg = colors.accent })

  highlight("Statement", { fg = colors.accent })
  highlight("Conditional", { fg = colors.accent })
  highlight("Repeat", { fg = colors.accent })
  highlight("Label", { fg = colors.accent })
  highlight("Operator", { fg = colors.fg })
  highlight("Keyword", { fg = colors.accent })
  highlight("Exception", { fg = colors.accent })

  highlight("PreProc", { fg = colors.accent })
  highlight("Include", { fg = colors.accent })
  highlight("Define", { fg = colors.accent })
  highlight("Macro", { fg = colors.accent })
  highlight("PreCondit", { fg = colors.accent })

  highlight("Type", { fg = colors.accent })
  highlight("StorageClass", { fg = colors.accent })
  highlight("Structure", { fg = colors.accent })
  highlight("Typedef", { fg = colors.accent })

  highlight("Special", { fg = colors.accent })
  highlight("SpecialChar", { fg = colors.accent })
  highlight("Tag", { fg = colors.accent })
  highlight("Delimiter", { fg = colors.fg })
  highlight("SpecialComment", { fg = colors.fg_dim })
  highlight("Debug", { fg = colors.accent })

  highlight("Underlined", { fg = colors.accent, style = "underline" })
  highlight("Error", { fg = colors.accent, style = "bold" })
  highlight("Todo", { fg = colors.bg, bg = colors.accent, style = "bold" })

  -- Treesitter
  highlight("@variable", { fg = colors.fg })
  highlight("@variable.builtin", { fg = colors.accent })
  highlight("@variable.parameter", { fg = colors.fg })
  highlight("@variable.member", { fg = colors.fg })

  highlight("@constant", { fg = colors.accent })
  highlight("@constant.builtin", { fg = colors.accent })

  highlight("@module", { fg = colors.fg })
  highlight("@label", { fg = colors.accent })

  highlight("@string", { fg = colors.string })
  highlight("@character", { fg = colors.string })
  highlight("@number", { fg = colors.accent })
  highlight("@boolean", { fg = colors.accent })
  highlight("@float", { fg = colors.accent })

  highlight("@function", { fg = colors.accent })
  highlight("@function.builtin", { fg = colors.accent })
  highlight("@function.macro", { fg = colors.accent })
  highlight("@function.method", { fg = colors.accent })

  highlight("@constructor", { fg = colors.accent })
  highlight("@keyword", { fg = colors.accent })
  highlight("@keyword.function", { fg = colors.accent })
  highlight("@keyword.operator", { fg = colors.accent })
  highlight("@keyword.return", { fg = colors.accent })

  highlight("@conditional", { fg = colors.accent })
  highlight("@repeat", { fg = colors.accent })

  highlight("@type", { fg = colors.accent })
  highlight("@type.builtin", { fg = colors.accent })

  highlight("@attribute", { fg = colors.accent })
  highlight("@property", { fg = colors.fg })

  highlight("@comment", { fg = colors.fg_dim })

  highlight("@punctuation.delimiter", { fg = colors.fg })
  highlight("@punctuation.bracket", { fg = colors.fg })
  highlight("@punctuation.special", { fg = colors.accent })

  highlight("@tag", { fg = colors.accent })
  highlight("@tag.attribute", { fg = colors.fg })
  highlight("@tag.delimiter", { fg = colors.fg })

  -- LSP Diagnostics - rust for errors, amber for warnings, patina for info
  highlight("DiagnosticError", { fg = colors.rust })
  highlight("DiagnosticWarn", { fg = colors.string })
  highlight("DiagnosticInfo", { fg = colors.accent })
  highlight("DiagnosticHint", { fg = colors.fg_dim })

  highlight("DiagnosticUnderlineError", { style = "undercurl", sp = colors.rust })
  highlight("DiagnosticUnderlineWarn", { style = "undercurl", sp = colors.string })
  highlight("DiagnosticUnderlineInfo", { style = "undercurl", sp = colors.accent })
  highlight("DiagnosticUnderlineHint", { style = "undercurl", sp = colors.fg_dim })

  highlight("LspReferenceText", { bg = colors.bg_light })
  highlight("LspReferenceRead", { bg = colors.bg_light })
  highlight("LspReferenceWrite", { bg = colors.bg_light })

  -- Git signs - semantic: green=add, amber=change, rust=delete
  highlight("GitSignsAdd", { fg = colors.accent })
  highlight("GitSignsChange", { fg = colors.string })
  highlight("GitSignsDelete", { fg = colors.rust })

  -- Diff highlighting
  highlight("DiffAdd", { bg = colors.accent_dim })
  highlight("DiffChange", { bg = colors.bg_light })
  highlight("DiffDelete", { fg = colors.rust, bg = colors.bg })
  highlight("DiffText", { bg = colors.accent_dim, style = "bold" })

  -- Terminal colors (ANSI 0-15)
  vim.g.terminal_color_0 = colors.bg           -- black
  vim.g.terminal_color_8 = colors.fg_dim       -- bright black
  vim.g.terminal_color_1 = colors.rust         -- red
  vim.g.terminal_color_9 = colors.rust         -- bright red
  vim.g.terminal_color_2 = colors.accent       -- green (patina)
  vim.g.terminal_color_10 = colors.accent      -- bright green
  vim.g.terminal_color_3 = colors.string       -- yellow (amber)
  vim.g.terminal_color_11 = colors.string      -- bright yellow
  vim.g.terminal_color_4 = colors.accent_dim   -- blue (deep patina)
  vim.g.terminal_color_12 = colors.accent      -- bright blue
  vim.g.terminal_color_5 = colors.rust         -- magenta (rust)
  vim.g.terminal_color_13 = colors.string      -- bright magenta
  vim.g.terminal_color_6 = colors.accent       -- cyan (patina)
  vim.g.terminal_color_14 = colors.accent      -- bright cyan
  vim.g.terminal_color_7 = colors.fg           -- white
  vim.g.terminal_color_15 = colors.fg          -- bright white
end

return M
