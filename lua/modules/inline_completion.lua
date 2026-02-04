local M = {}

M.config = {
  debounce_ms = 300,
  model = "haiku",
  context_lines = 5,
  enabled_filetypes = nil, -- nil = all
}

local state = {
  pending_job = nil,
  debounce_timer = nil,
  ghost_extmark_id = nil,
  ghost_extmark_buf = nil,
  current_completion = nil,
  ns = nil,
  request_id = 0,
}

local SYSTEM_PROMPT = [[You are an inline code completion engine. Given context, output ONLY the completion text that should appear after the cursor. No explanations, no markdown, no code blocks - just the raw completion text. Complete the current line or add a few lines at most. Be concise.]]

local function get_namespace()
  if not state.ns then
    state.ns = vim.api.nvim_create_namespace("inline_completion")
  end
  return state.ns
end

local function clear_ghost_text()
  if state.ghost_extmark_id and state.ghost_extmark_buf then
    pcall(vim.api.nvim_buf_del_extmark, state.ghost_extmark_buf, get_namespace(), state.ghost_extmark_id)
    state.ghost_extmark_id = nil
    state.ghost_extmark_buf = nil
  end
  state.current_completion = nil
end

local function cancel_pending()
  if state.pending_job then
    pcall(vim.fn.jobstop, state.pending_job)
    state.pending_job = nil
  end
  state.request_id = state.request_id + 1
end

local function show_ghost_text(completion)
  if not completion or completion == "" then return end
  if vim.fn.mode() ~= "i" then return end

  clear_ghost_text()
  state.current_completion = completion

  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local col = cursor[2]

  -- Split completion into lines
  local lines = vim.split(completion, "\n", { plain = true })
  if #lines == 0 then return end

  local virt_text = {}
  local virt_lines = {}

  -- First line as inline virtual text
  if lines[1] and lines[1] ~= "" then
    virt_text = { { lines[1], "Comment" } }
  end

  -- Remaining lines as virtual lines below
  for i = 2, #lines do
    table.insert(virt_lines, { { lines[i], "Comment" } })
  end

  local opts = {
    virt_text = virt_text,
    virt_text_pos = "inline",
    hl_mode = "combine",
  }
  if #virt_lines > 0 then
    opts.virt_lines = virt_lines
  end

  local buf = vim.api.nvim_get_current_buf()
  state.ghost_extmark_id = vim.api.nvim_buf_set_extmark(buf, get_namespace(), row, col, opts)
  state.ghost_extmark_buf = buf
end

local function gather_context()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  local col = cursor[2]

  local buf_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  if #buf_lines == 0 then return nil end

  -- Previous lines (up to context_lines)
  local start_line = math.max(1, row - M.config.context_lines)
  local prev_lines = {}
  for i = start_line, row - 1 do
    table.insert(prev_lines, buf_lines[i])
  end

  -- Current line up to cursor
  local current_line = buf_lines[row] or ""
  current_line = current_line:sub(1, col)

  -- Get filetype for context
  local ft = vim.bo.filetype

  local prompt = string.format(
    "<filetype>%s</filetype>\n<prev-lines>\n%s\n</prev-lines>\n<current-line>%s</current-line>",
    ft,
    table.concat(prev_lines, "\n"),
    current_line
  )

  return prompt
end

local function request_completion()
  local prompt = gather_context()
  if not prompt then return end

  cancel_pending()

  state.request_id = state.request_id + 1
  local this_request_id = state.request_id
  local request_buf = vim.api.nvim_get_current_buf()
  local stdout_data = {}

  local json_schema = vim.json.encode({
    type = "object",
    properties = {
      completion = { type = "string" },
    },
    required = { "completion" },
  })

  local cmd = {
    "claude",
    "-p",
    "--system-prompt", SYSTEM_PROMPT,
    "--allowedTools", "",
    "--model", M.config.model,
    "--output-format", "json",
    "--json-schema", json_schema,
  }

  state.pending_job = vim.fn.jobstart(cmd, {
    stdin = "pipe",
    stdout_buffered = false,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(stdout_data, line)
          end
        end
      end
    end,
    on_exit = function(_, exit_code)
      state.pending_job = nil
      if exit_code ~= 0 then return end
      if state.request_id ~= this_request_id then return end

      vim.schedule(function()
        if state.request_id ~= this_request_id then return end
        if vim.api.nvim_get_current_buf() ~= request_buf then return end

        local output = table.concat(stdout_data, "")
        if output == "" then return end

        local ok, parsed = pcall(vim.json.decode, output)
        if ok and parsed and parsed.structured_output and parsed.structured_output.completion then
          show_ghost_text(parsed.structured_output.completion)
        end
      end)
    end,
  })

  if state.pending_job and state.pending_job > 0 then
    vim.fn.chansend(state.pending_job, prompt)
    vim.fn.chanclose(state.pending_job, "stdin")
  end
end

local function trigger_completion()
  if vim.fn.mode() ~= "i" then return end

  cancel_pending()

  -- Check filetype filter
  if M.config.enabled_filetypes then
    local ft = vim.bo.filetype
    local allowed = false
    for _, v in ipairs(M.config.enabled_filetypes) do
      if v == ft then
        allowed = true
        break
      end
    end
    if not allowed then return end
  end

  if not state.debounce_timer then
    state.debounce_timer = vim.uv.new_timer()
  end

  state.debounce_timer:stop()
  state.debounce_timer:start(M.config.debounce_ms, 0, vim.schedule_wrap(function()
    request_completion()
  end))
end

local function accept_completion()
  if not state.current_completion then return false end
  if vim.fn.mode() ~= "i" then return false end

  local completion = state.current_completion
  clear_ghost_text()

  vim.schedule(function()
    local lines = vim.split(completion, "\n", { plain = true })
    vim.api.nvim_put(lines, "c", true, true)
  end)

  return true
end

local function setup_autocmds()
  local group = vim.api.nvim_create_augroup("inline_completion", { clear = true })

  vim.api.nvim_create_autocmd("TextChangedI", {
    group = group,
    callback = function()
      clear_ghost_text()
      trigger_completion()
    end,
  })

  vim.api.nvim_create_autocmd("InsertLeave", {
    group = group,
    callback = function()
      cancel_pending()
      clear_ghost_text()
      if state.debounce_timer then
        state.debounce_timer:stop()
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    group = group,
    callback = function()
      cancel_pending()
      clear_ghost_text()
    end,
  })
end

local function setup_keymaps()
  vim.keymap.set("i", "<Tab>", function()
    if accept_completion() then
      return ""
    end
    return "<Tab>"
  end, { expr = true, noremap = true, desc = "Accept inline completion or Tab" })

  vim.keymap.set("i", "<Esc>", function()
    clear_ghost_text()
    cancel_pending()
    return "<Esc>"
  end, { expr = true, noremap = true, desc = "Clear completion and exit insert" })
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  setup_autocmds()
  setup_keymaps()
end

function M.enable()
  setup_autocmds()
end

function M.disable()
  cancel_pending()
  clear_ghost_text()
  if state.debounce_timer then
    state.debounce_timer:stop()
    state.debounce_timer:close()
    state.debounce_timer = nil
  end
  pcall(vim.api.nvim_del_augroup_by_name, "inline_completion")
end

return M
