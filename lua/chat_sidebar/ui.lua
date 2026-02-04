-- Sidebar window management
local M = {}

local state = {
    buf = nil,
    win = nil,
    input_buf = nil,
    input_win = nil,
    editor_win = nil, -- window that was active when sidebar opened
    width_ratio = 0.3, -- ratio of total columns
    input_height = 3,
    spinner_timer = nil,
    spinner_frame = 1,
    spinner_line = nil, -- original line content before spinner
    queued_count = 0,
}

local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

local function calculate_width()
    return math.floor(vim.o.columns * state.width_ratio)
end

function M.set_width_ratio(ratio)
    state.width_ratio = ratio
    if M.is_open() then
        vim.api.nvim_win_set_width(state.win, calculate_width())
    end
end

local function on_resize()
    if M.is_open() then
        vim.api.nvim_win_set_width(state.win, calculate_width())
    end
    if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
        vim.api.nvim_win_set_height(state.input_win, state.input_height)
    end
end

local function create_scratch_buffer()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "markdown"
    return buf
end

function M.is_open()
    return state.win and vim.api.nvim_win_is_valid(state.win)
end

function M.open()
    if M.is_open() then
        return state.buf, state.win, state.input_buf, state.input_win
    end

    -- Track which window was active before opening sidebar
    state.editor_win = vim.api.nvim_get_current_win()

    if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
        state.buf = create_scratch_buffer()
    end
    if not state.input_buf or not vim.api.nvim_buf_is_valid(state.input_buf) then
        state.input_buf = create_scratch_buffer()
    end

    -- Create main chat window
    vim.cmd("botright vsplit")
    state.win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(state.win, state.buf)
    vim.api.nvim_win_set_width(state.win, calculate_width())

    local function set_win_opts(win)
        vim.wo[win].number = false
        vim.wo[win].relativenumber = false
        vim.wo[win].signcolumn = "no"
        vim.wo[win].wrap = true
        vim.wo[win].linebreak = true
    end
    set_win_opts(state.win)

    -- Create input window at bottom
    vim.cmd("belowright split")
    state.input_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(state.input_win, state.input_buf)
    vim.api.nvim_win_set_height(state.input_win, state.input_height)
    set_win_opts(state.input_win)

    -- Focus input window
    vim.api.nvim_set_current_win(state.input_win)

    return state.buf, state.win, state.input_buf, state.input_win
end

function M.close()
    if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
        vim.api.nvim_win_close(state.input_win, true)
        state.input_win = nil
    end
    if M.is_open() then
        vim.api.nvim_win_close(state.win, true)
        state.win = nil
    end
end

function M.toggle()
    if M.is_open() then
        M.close()
    else
        M.open()
    end
end

function M.get_buf()
    return state.buf
end

function M.get_win()
    return state.win
end

function M.get_input_buf()
    return state.input_buf
end

function M.get_input_win()
    return state.input_win
end

function M.get_editor_win()
    -- Return tracked window if still valid
    if state.editor_win and vim.api.nvim_win_is_valid(state.editor_win) then
        return state.editor_win
    end
    return nil
end

function M.get_input_text()
    if not state.input_buf or not vim.api.nvim_buf_is_valid(state.input_buf) then
        return ""
    end
    local lines = vim.api.nvim_buf_get_lines(state.input_buf, 0, -1, false)
    return table.concat(lines, "\n")
end

function M.clear_input()
    if not state.input_buf or not vim.api.nvim_buf_is_valid(state.input_buf) then
        return
    end
    vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, {})
end

function M.focus_input()
    if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
        vim.api.nvim_set_current_win(state.input_win)
    end
end

function M.append_lines(lines)
    if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
        return
    end
    vim.bo[state.buf].modifiable = true
    local count = vim.api.nvim_buf_line_count(state.buf)
    -- If buffer is empty (single empty line), replace it
    local first_line = vim.api.nvim_buf_get_lines(state.buf, 0, 1, false)[1]
    if count == 1 and first_line == "" then
        vim.api.nvim_buf_set_lines(state.buf, 0, 1, false, lines)
    else
        vim.api.nvim_buf_set_lines(state.buf, count, count, false, lines)
    end
    vim.bo[state.buf].modifiable = false
    M.scroll_to_bottom()
end

function M.append_text(text)
    if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
        return
    end
    vim.bo[state.buf].modifiable = true
    local count = vim.api.nvim_buf_line_count(state.buf)
    local last_line = vim.api.nvim_buf_get_lines(state.buf, count - 1, count, false)[1] or ""
    local new_text = last_line .. text
    local new_lines = vim.split(new_text, "\n", { plain = true })
    vim.api.nvim_buf_set_lines(state.buf, count - 1, count, false, new_lines)
    vim.bo[state.buf].modifiable = false
    M.scroll_to_bottom()
end

function M.clear()
    if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
        return
    end
    vim.bo[state.buf].modifiable = true
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, {})
    vim.bo[state.buf].modifiable = false
end

function M.scroll_to_bottom()
    if M.is_open() then
        local count = vim.api.nvim_buf_line_count(state.buf)
        vim.api.nvim_win_set_cursor(state.win, { count, 0 })
    end
end

-- Auto-resize on terminal resize
vim.api.nvim_create_autocmd("VimResized", {
    callback = on_resize,
})

function M.focus_chat()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_set_current_win(state.win)
    end
end

function M.show_spinner(label)
    M.hide_spinner() -- clear any existing
    state.spinner_frame = 1

    if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end

    -- Store original last line
    local count = vim.api.nvim_buf_line_count(state.buf)
    state.spinner_line = vim.api.nvim_buf_get_lines(state.buf, count - 1, count, false)[1] or ""

    local function update()
        if not state.spinner_timer then return end
        if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
            M.hide_spinner()
            return
        end

        local frame = spinner_frames[state.spinner_frame]
        state.spinner_frame = (state.spinner_frame % #spinner_frames) + 1

        vim.bo[state.buf].modifiable = true
        local cnt = vim.api.nvim_buf_line_count(state.buf)
        local new_line = state.spinner_line .. frame .. " " .. label
        vim.api.nvim_buf_set_lines(state.buf, cnt - 1, cnt, false, { new_line })
        vim.bo[state.buf].modifiable = false
    end

    state.spinner_timer = vim.uv.new_timer()
    state.spinner_timer:start(0, 80, vim.schedule_wrap(update))
end

function M.hide_spinner()
    if state.spinner_timer then
        state.spinner_timer:stop()
        state.spinner_timer:close()
        state.spinner_timer = nil
    end

    -- Restore original line
    if state.spinner_line ~= nil and state.buf and vim.api.nvim_buf_is_valid(state.buf) then
        vim.bo[state.buf].modifiable = true
        local count = vim.api.nvim_buf_line_count(state.buf)
        vim.api.nvim_buf_set_lines(state.buf, count - 1, count, false, { state.spinner_line })
        vim.bo[state.buf].modifiable = false
        state.spinner_line = nil
    end
end

function M.show_queued_indicator(count)
    state.queued_count = count
    if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
        vim.wo[state.input_win].winbar = "queued " .. count
    end
end

function M.hide_queued_indicator()
    state.queued_count = 0
    if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
        vim.wo[state.input_win].winbar = ""
    end
end

return M
