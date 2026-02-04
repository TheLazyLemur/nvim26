local M = {}

local config = {
    width_ratio = 0.8,
    height_ratio = 0.8,
    border = "rounded",
}

local state = {}
local count = 0

local get_terminal_id = function()
    count = count + 1
    return "Terminal " .. tostring(count)
end

local function new_terminal(name)
    local terminal_name = name or nil
    if not terminal_name then
        terminal_name = get_terminal_id()
    end

    local ok, buf = pcall(vim.api.nvim_create_buf, false, true)
    if ok == false then
        return nil, "Could not create terminal - error createing buffer"
    end

    return {
        name = terminal_name,
        buf = buf,
        win = nil,
    }, nil
end

local function find_terminal_by_name(name)
    for _, term in ipairs(state) do
        if term.name == name then
            return term
        end
    end
    return nil
end

local function get_window_config()
    local width = vim.o.columns
    local height = vim.o.lines

    local win_width = math.floor(width * config.width_ratio)
    local win_height = math.floor(height * config.height_ratio)

    local col = math.floor((width - win_width) / 2)
    local row = math.floor((height - win_height) / 2)

    return {
        relative = "editor",
        width = win_width,
        height = win_height,
        col = col,
        row = row,
        style = "minimal",
        border = config.border,
    }
end

local function toggle_terminal(term)
    if not term then
        vim.notify("No terminal selected", vim.log.levels.ERROR)
        return
    end
    if term.win and vim.api.nvim_win_is_valid(term.win) then
        vim.api.nvim_win_close(term.win, true)
        term.win = nil
    else
        local win_config = get_window_config()
        local ok, win = pcall(vim.api.nvim_open_win, term.buf, true, win_config)
        if not ok then
            vim.notify("Failed to open floating window", vim.log.levels.ERROR)
            return
        end
        term.win = win

        vim.wo[win].number = false
        vim.wo[win].relativenumber = false
        vim.wo[win].signcolumn = 'no'

        if vim.bo[term.buf].buftype ~= 'terminal' then
            local job_id = vim.fn.termopen(vim.o.shell)
            if job_id <= 0 then
                vim.notify("Failed to start terminal", vim.log.levels.ERROR)
                return
            end
        end

        vim.cmd.startinsert()
    end
end

function M.close_all()
    for _, term in ipairs(state) do
        if term.win then
            vim.api.nvim_win_close(term.win, true)
            term.win = nil
        end
    end
end

function M.add_terminal(name)
    local term, err = new_terminal(name)
    if err ~= nil then
        vim.notify(err, vim.log.levels.ERROR)
        return
    end
    table.insert(state, term)
end

function M.add_named_terminal()
    vim.ui.input({ prompt = 'Enter terminal name: ' }, function(input)
        if input ~= nil then
            M.add_terminal(input)
        else
            return
        end
    end)
end

function M.select_terminal_menu()
    -- If no terminal exists, create one
    if #state == 0 then
        vim.notify("No terminals available, creating one", vim.log.levels.INFO)
        M.add_terminal()
    end

    -- If only one terminal exists, open that, do not show menu
    if #state == 1 then
        local term = state[1]
        toggle_terminal(term)
        return
    end

    M.close_all()

    local names = {}
    for _, term in ipairs(state) do
        table.insert(names, term.name)
    end
    vim.ui.select(names, { prompt = "Select terminal to toggle:" }, function(choice)
        if choice then
            local term = find_terminal_by_name(choice)
            toggle_terminal(term)
        end
    end)
end

return M
