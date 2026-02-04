local M = {}

M.config = {
  width = 30,
  show_hidden = false,
  close_on_open = false,
  icons = {
    folder_closed = "",
    folder_open = "",
    file = "",
    -- File type icons
    lua = "",
    js = "",
    ts = "",
    jsx = "",
    tsx = "",
    json = "",
    md = "",
    vim = "",
    git = "",
    yaml = "",
    yml = "",
    toml = "",
    sh = "",
    zsh = "",
    bash = "",
    py = "",
    rb = "",
    go = "",
    rs = "",
    c = "",
    cpp = "",
    h = "",
    css = "",
    html = "",
    svg = "",
    png = "",
    jpg = "",
    jpeg = "",
    gif = "",
    lock = "",
    conf = "",
    txt = "",
  },
}

local state = {
  buf = nil,
  win = nil,
  cwd = nil,
  expanded = {},
  entries = {},
}

local function setup_highlights()
  local hl = vim.api.nvim_set_hl
  hl(0, "FileTreeDirectory", { link = "Directory" })
  hl(0, "FileTreeFile", { link = "Normal" })
  hl(0, "FileTreeFolderIcon", { link = "Statement" })
  hl(0, "FileTreeFileIcon", { link = "Type" })
  hl(0, "FileTreeHidden", { link = "Comment" })
end

local function is_directory(path)
  return vim.fn.isdirectory(path) == 1
end

local function get_icon(entry)
  if entry.type == "directory" then
    return state.expanded[entry.path] and M.config.icons.folder_open or M.config.icons.folder_closed
  end

  local ext = entry.name:match("%.([^%.]+)$")
  if ext then
    ext = ext:lower()
    if M.config.icons[ext] then
      return M.config.icons[ext]
    end
  end

  -- Special files
  local name = entry.name:lower()
  if name == ".gitignore" or name == ".gitmodules" then
    return M.config.icons.git
  end
  if name:match("^%.") then
    return M.config.icons.conf
  end

  return M.config.icons.file
end

local function get_entries(dir, show_hidden)
  local entries = {}
  local handle = vim.loop.fs_scandir(dir)
  if not handle then return entries end

  while true do
    local name, type = vim.loop.fs_scandir_next(handle)
    if not name then break end
    if show_hidden or name:sub(1, 1) ~= "." then
      table.insert(entries, {
        name = name,
        path = dir .. "/" .. name,
        type = type or (is_directory(dir .. "/" .. name) and "directory" or "file"),
        hidden = name:sub(1, 1) == ".",
      })
    end
  end

  table.sort(entries, function(a, b)
    if a.type == "directory" and b.type ~= "directory" then return true end
    if a.type ~= "directory" and b.type == "directory" then return false end
    return a.name < b.name
  end)

  return entries
end

local function build_tree(dir, depth)
  local lines = {}
  local entries = get_entries(dir, M.config.show_hidden)

  for _, entry in ipairs(entries) do
    local indent = string.rep("  ", depth)
    local icon = get_icon(entry)

    table.insert(lines, {
      text = indent .. icon .. " " .. entry.name,
      entry = entry,
      depth = depth,
      icon = icon,
      indent_len = #indent,
    })

    if entry.type == "directory" and state.expanded[entry.path] then
      local children = build_tree(entry.path, depth + 1)
      for _, child in ipairs(children) do
        table.insert(lines, child)
      end
    end
  end

  return lines
end

local function apply_highlights()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end

  local ns = vim.api.nvim_create_namespace("filetree")
  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)

  for i, item in ipairs(state.entries) do
    local row = i - 1
    local indent_len = item.indent_len
    local icon_end = indent_len + #item.icon

    -- Highlight icon
    local icon_hl = item.entry.type == "directory" and "FileTreeFolderIcon" or "FileTreeFileIcon"
    vim.api.nvim_buf_add_highlight(state.buf, ns, icon_hl, row, indent_len, icon_end)

    -- Highlight name
    local name_hl
    if item.entry.hidden then
      name_hl = "FileTreeHidden"
    elseif item.entry.type == "directory" then
      name_hl = "FileTreeDirectory"
    else
      name_hl = "FileTreeFile"
    end
    vim.api.nvim_buf_add_highlight(state.buf, ns, name_hl, row, icon_end + 1, -1)
  end
end

local function render()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end

  local tree = build_tree(state.cwd, 0)
  state.entries = tree

  local lines = {}
  for _, item in ipairs(tree) do
    table.insert(lines, item.text)
  end

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false

  apply_highlights()
end

local function get_entry_at_cursor()
  local row = vim.api.nvim_win_get_cursor(state.win)[1]
  return state.entries[row]
end

local function find_entry_index(path)
  for i, item in ipairs(state.entries) do
    if item.entry.path == path then return i end
  end
  return nil
end

local function find_other_window()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= state.win and vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      local bt = vim.bo[buf].buftype
      if bt == "" or bt == nil then
        return win
      end
    end
  end
  return nil
end

local function action_open()
  local item = get_entry_at_cursor()
  if not item then return end

  if item.entry.type == "directory" then
    state.expanded[item.entry.path] = not state.expanded[item.entry.path]
    render()
  else
    local target_win = find_other_window()
    if M.config.close_on_open then
      M.close()
      vim.cmd.edit(item.entry.path)
    elseif target_win then
      vim.api.nvim_set_current_win(target_win)
      vim.cmd.edit(item.entry.path)
    else
      vim.cmd("wincmd l")
      vim.cmd.edit(item.entry.path)
    end
  end
end

local function action_open_split()
  local item = get_entry_at_cursor()
  if not item or item.entry.type == "directory" then return end

  local target_win = find_other_window()
  if M.config.close_on_open then
    M.close()
  elseif target_win then
    vim.api.nvim_set_current_win(target_win)
  else
    vim.cmd("wincmd l")
  end
  vim.cmd.split(item.entry.path)
end

local function action_open_vsplit()
  local item = get_entry_at_cursor()
  if not item or item.entry.type == "directory" then return end

  local target_win = find_other_window()
  if M.config.close_on_open then
    M.close()
  elseif target_win then
    vim.api.nvim_set_current_win(target_win)
  else
    vim.cmd("wincmd l")
  end
  vim.cmd.vsplit(item.entry.path)
end

local function action_parent()
  state.cwd = vim.fn.fnamemodify(state.cwd, ":h")
  state.expanded = {}
  render()
end

local function action_refresh()
  render()
end

local function action_toggle_hidden()
  M.config.show_hidden = not M.config.show_hidden
  render()
end

local function action_cd()
  local item = get_entry_at_cursor()
  if not item or item.entry.type ~= "directory" then return end
  state.cwd = item.entry.path
  state.expanded = {}
  render()
end

local function setup_keymaps()
  local opts = { buffer = state.buf, nowait = true }
  vim.keymap.set("n", "<CR>", action_open, opts)
  vim.keymap.set("n", "l", action_open, opts)
  vim.keymap.set("n", "h", action_parent, opts)
  vim.keymap.set("n", "s", action_open_split, opts)
  vim.keymap.set("n", "v", action_open_vsplit, opts)
  vim.keymap.set("n", "R", action_refresh, opts)
  vim.keymap.set("n", ".", action_toggle_hidden, opts)
  vim.keymap.set("n", "c", action_cd, opts)
  vim.keymap.set("n", "q", M.close, opts)
  vim.keymap.set("n", "<Esc>", M.close, opts)
end

function M.open(dir)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
    return
  end

  setup_highlights()
  state.cwd = dir or vim.fn.getcwd()

  state.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buf].buftype = "nofile"
  vim.bo[state.buf].bufhidden = "wipe"
  vim.bo[state.buf].swapfile = false
  vim.bo[state.buf].filetype = "filetree"

  vim.cmd("topleft " .. M.config.width .. "vsplit")
  state.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.win, state.buf)

  vim.wo[state.win].number = false
  vim.wo[state.win].relativenumber = false
  vim.wo[state.win].signcolumn = "no"
  vim.wo[state.win].foldcolumn = "0"
  vim.wo[state.win].cursorline = true
  vim.wo[state.win].wrap = false

  setup_keymaps()
  render()

  vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup("filetree_reveal", { clear = true }),
    callback = function(ev)
      if vim.bo[ev.buf].filetype == "filetree" then return end
      if vim.bo[ev.buf].buftype ~= "" then return end
      local path = vim.api.nvim_buf_get_name(ev.buf)
      if path ~= "" then M.reveal_file(path) end
    end,
  })
end

function M.close()
  pcall(vim.api.nvim_del_augroup_by_name, "filetree_reveal")
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
  state.buf = nil
end

function M.toggle(dir)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    M.close()
  else
    M.open(dir)
  end
end

function M.reveal_file(filepath)
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then return end

  filepath = vim.fn.fnamemodify(filepath, ":p")
  if not vim.startswith(filepath, state.cwd .. "/") then return end

  -- Expand parent dirs
  local rel = filepath:sub(#state.cwd + 2)
  local parts = vim.split(rel, "/", { plain = true })
  table.remove(parts) -- remove filename

  local current = state.cwd
  for _, part in ipairs(parts) do
    current = current .. "/" .. part
    state.expanded[current] = true
  end

  render()

  local idx = find_entry_index(filepath)
  if idx then
    vim.api.nvim_win_set_cursor(state.win, { idx, 0 })
  end
end

return M
