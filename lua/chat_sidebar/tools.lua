-- Tool registry for chat sidebar
local M = {}
local ui = require("chat_sidebar.ui")

M.registry = {}
M.config = {
    follow_agent = true, -- open files agent reads in a buffer
}

-- Register a tool with name, schema (Anthropic format), and executor function
function M.register(name, schema, executor)
    M.registry[name] = {
        schema = schema,
        execute = executor,
    }
end

function M.configure(opts)
    M.config = vim.tbl_extend("force", M.config, opts or {})
end

function M.get(name)
    return M.registry[name]
end

function M.list()
    return vim.tbl_keys(M.registry)
end

-- Get all tool schemas for API request
function M.get_schemas()
    local schemas = {}
    for _, tool in pairs(M.registry) do
        table.insert(schemas, tool.schema)
    end
    return schemas
end

-- Execute a tool by name with input (sync - for non-blocking tools)
function M.execute(name, input)
    local tool = M.registry[name]
    if not tool then
        return { success = false, error = "Unknown tool: " .. name }
    end
    local ok, result = pcall(tool.execute, input)
    if not ok then
        return { success = false, error = tostring(result) }
    end
    return result
end

-- Execute a tool asynchronously with callback
-- callback(result) where result = { success, message/error }
function M.execute_async(name, input, callback)
    local tool = M.registry[name]
    if not tool then
        callback({ success = false, error = "Unknown tool: " .. name })
        return
    end

    -- Check if tool has async executor
    if tool.execute_async then
        local ok, err = pcall(tool.execute_async, input, callback)
        if not ok then
            callback({ success = false, error = tostring(err) })
        end
    else
        -- Fallback to sync execution via vim.schedule
        vim.schedule(function()
            local ok, result = pcall(tool.execute, input)
            if not ok then
                callback({ success = false, error = tostring(result) })
            else
                callback(result)
            end
        end)
    end
end

-- Helper to register tool with both sync and async executors
function M.register_async(name, schema, sync_executor, async_executor)
    M.registry[name] = {
        schema = schema,
        execute = sync_executor,
        execute_async = async_executor,
    }
end

-- Register set_colorscheme tool
M.register("set_colorscheme", {
    name = "set_colorscheme",
    description = "Change Neovim's colorscheme. For oxidized variants (dark, light, machinery), uses the custom oxidized colorscheme. For other names, uses vim.cmd.colorscheme().",
    input_schema = {
        type = "object",
        properties = {
            name = {
                type = "string",
                description = "Colorscheme name. For oxidized variants use: 'oxidized dark', 'oxidized light', or 'oxidized machinery'. For other colorschemes, just use the name (e.g., 'catppuccin', 'gruvbox').",
            },
        },
        required = { "name" },
    },
}, function(input)
    local name = input.name
    if not name then
        return { success = false, error = "Missing colorscheme name" }
    end

    -- Handle oxidized variants (plain "oxidized" defaults to dark)
    local oxidized_variant = name:match("^oxidized%s*(%w*)$")
    if oxidized_variant then
        local variant = oxidized_variant == "" and "dark" or oxidized_variant
        local valid = { dark = true, light = true, machinery = true }
        if not valid[variant] then
            return { success = false, error = "Invalid oxidized variant: " .. variant .. ". Valid: dark, light, machinery" }
        end
        require("modules.colorscheme").setup(variant)
        return { success = true, message = "Changed to oxidized " .. variant }
    end

    -- Handle other colorschemes
    local ok, err = pcall(vim.cmd.colorscheme, name)
    if not ok then
        return { success = false, error = "Failed to set colorscheme: " .. tostring(err) }
    end
    return { success = true, message = "Changed to " .. name }
end)

-- search_files: ripgrep wrapper (content search)
local function build_search_cmd(input)
    local pattern = input.pattern
    if not pattern or pattern == "" then
        return nil, "Missing search pattern"
    end

    local cmd = { "rg", "--line-number", "--no-heading", "--color=never" }
    local max_results = input.max_results or 50
    table.insert(cmd, "--max-count=" .. max_results)

    if input.glob then
        table.insert(cmd, "--glob")
        table.insert(cmd, input.glob)
    end

    table.insert(cmd, "--")
    table.insert(cmd, pattern)

    if input.path then
        table.insert(cmd, input.path)
    end

    return cmd, nil
end

local function parse_rg_result(result)
    if result.code ~= 0 and result.code ~= 1 then
        return { success = false, error = result.stderr or "rg failed" }
    end

    local output = result.stdout or ""
    if output == "" then
        return { success = true, message = "No matches found" }
    end

    local lines = vim.split(output, "\n", { trimempty = true })
    return { success = true, message = table.concat(lines, "\n") }
end

M.register_async("search_files", {
    name = "search_files",
    description = "Search FILE CONTENTS for a regex pattern using ripgrep. Use 'glob' to filter which files to search. Example: pattern='function foo', glob='*.lua'",
    input_schema = {
        type = "object",
        properties = {
            pattern = {
                type = "string",
                description = "Regex pattern to search for IN FILE CONTENTS. NOT a file glob. Examples: 'function\\s+\\w+', 'TODO', 'import.*react'",
            },
            path = {
                type = "string",
                description = "Directory or file to search in. Defaults to cwd.",
            },
            glob = {
                type = "string",
                description = "Filter FILES by glob pattern. Examples: '*.lua', '*.ts', '**/*.md'. This filters which files to search, NOT what to search for.",
            },
            max_results = {
                type = "number",
                description = "Max results to return. Default 50.",
            },
        },
        required = { "pattern" },
    },
},
-- sync executor
function(input)
    local cmd, err = build_search_cmd(input)
    if not cmd then return { success = false, error = err } end
    return parse_rg_result(vim.system(cmd, { text = true }):wait())
end,
-- async executor
function(input, callback)
    local cmd, err = build_search_cmd(input)
    if not cmd then
        callback({ success = false, error = err })
        return
    end
    vim.system(cmd, { text = true }, function(result)
        vim.schedule(function()
            callback(parse_rg_result(result))
        end)
    end)
end)

-- list_files: find files by glob pattern
local function build_list_cmd(input)
    local glob = input.glob
    if not glob or glob == "" then
        return nil, "Missing glob pattern"
    end

    local cmd = { "rg", "--files", "--glob", glob }
    if input.path then
        table.insert(cmd, input.path)
    end
    return cmd, nil
end

local function parse_list_result(result, max_results)
    if result.code ~= 0 and result.code ~= 1 then
        return { success = false, error = result.stderr or "rg --files failed" }
    end

    local output = result.stdout or ""
    if output == "" then
        return { success = true, message = "No files found" }
    end

    local lines = vim.split(output, "\n", { trimempty = true })
    max_results = max_results or 100
    if #lines > max_results then
        local total = #lines
        lines = vim.list_slice(lines, 1, max_results)
        table.insert(lines, string.format("... truncated (%d more)", total - max_results))
    end

    return { success = true, message = table.concat(lines, "\n") }
end

M.register_async("list_files", {
    name = "list_files",
    description = "List files matching a glob pattern. Use this to find files by name/extension, NOT to search file contents.",
    input_schema = {
        type = "object",
        properties = {
            glob = {
                type = "string",
                description = "Glob pattern. Examples: '*.lua', '**/*.ts', 'src/**/*.jsx'",
            },
            path = {
                type = "string",
                description = "Directory to search in. Defaults to cwd.",
            },
            max_results = {
                type = "number",
                description = "Max files to return. Default 100.",
            },
        },
        required = { "glob" },
    },
},
-- sync executor
function(input)
    local cmd, err = build_list_cmd(input)
    if not cmd then return { success = false, error = err } end
    return parse_list_result(vim.system(cmd, { text = true }):wait(), input.max_results)
end,
-- async executor
function(input, callback)
    local cmd, err = build_list_cmd(input)
    if not cmd then
        callback({ success = false, error = err })
        return
    end
    vim.system(cmd, { text = true }, function(result)
        vim.schedule(function()
            callback(parse_list_result(result, input.max_results))
        end)
    end)
end)

-- Shared helpers
local function resolve_path(path)
    if not path:match("^/") then
        return vim.fn.getcwd() .. "/" .. path
    end
    return path
end

local function find_editor_window()
    -- Prefer tracked editor window from when sidebar opened
    local tracked = ui.get_editor_win()
    if tracked then
        return tracked
    end
    -- Fallback: heuristic (original window may have been closed)
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].buftype ~= "nofile" then
            return win
        end
    end
    return vim.api.nvim_list_wins()[1]
end

local function get_filetype_from_path(path)
    local ext = vim.fn.fnamemodify(path, ":e")
    local ft_map = { lua = "lua", py = "python", js = "javascript", ts = "typescript", md = "markdown", json = "json", yaml = "yaml", yml = "yaml" }
    return ft_map[ext] or ext
end

local diff_state = nil

local function close_diff_view(state, open_file)
    if not state then return end

    -- Clear autocmd
    if state.autocmd_id then
        pcall(vim.api.nvim_del_autocmd, state.autocmd_id)
    end

    -- diffoff on both windows
    for _, win in ipairs({ state.orig_win, state.prop_win }) do
        if win and vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_call(win, function() vim.cmd("diffoff") end)
        end
    end

    -- Close proposed window
    if state.prop_win and vim.api.nvim_win_is_valid(state.prop_win) then
        pcall(vim.api.nvim_win_close, state.prop_win, true)
    end

    -- Open actual file in orig_win BEFORE deleting scratch buffers
    if open_file and state.orig_win and vim.api.nvim_win_is_valid(state.orig_win) then
        local path = resolve_path(state.filepath)
        vim.api.nvim_set_current_win(state.orig_win)
        vim.cmd("edit " .. vim.fn.fnameescape(path))
    end

    -- Now safe to delete scratch buffers
    for _, buf in ipairs({ state.orig_buf, state.prop_buf }) do
        if buf and vim.api.nvim_buf_is_valid(buf) then
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
    end

    diff_state = nil
end

local function open_diff_view(original_lines, proposed_lines, filepath, on_accept, on_reject)
    local ft = get_filetype_from_path(filepath)

    -- Create original buffer (left)
    local orig_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(orig_buf, 0, -1, false, original_lines)
    vim.bo[orig_buf].filetype = ft
    vim.bo[orig_buf].modifiable = false
    vim.bo[orig_buf].buftype = "nofile"
    vim.api.nvim_buf_set_name(orig_buf, "original://" .. filepath)

    -- Create proposed buffer (right)
    local prop_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(prop_buf, 0, -1, false, proposed_lines)
    vim.bo[prop_buf].filetype = ft
    vim.bo[prop_buf].modifiable = false
    vim.bo[prop_buf].buftype = "nofile"
    vim.api.nvim_buf_set_name(prop_buf, "proposed://" .. filepath)

    local target_win = find_editor_window()

    -- Open original in target window
    vim.api.nvim_set_current_win(target_win)
    vim.api.nvim_win_set_buf(target_win, orig_buf)
    vim.cmd("diffthis")
    local orig_win = target_win

    -- Split right for proposed
    vim.cmd("vsplit")
    local prop_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(prop_win, prop_buf)
    vim.cmd("diffthis")

    -- Store state
    local state = {
        orig_buf = orig_buf,
        prop_buf = prop_buf,
        orig_win = orig_win,
        prop_win = prop_win,
        filepath = filepath,
        proposed_lines = proposed_lines,
        on_accept = on_accept,
        on_reject = on_reject,
    }

    -- Keymaps on proposed buffer
    local function accept()
        local path = resolve_path(state.filepath)
        local ok, err = pcall(vim.fn.writefile, state.proposed_lines, path)
        close_diff_view(state, true)
        if ok then
            state.on_accept()
        else
            state.on_reject("Write failed: " .. tostring(err))
        end
    end

    local function reject()
        close_diff_view(state, vim.fn.filereadable(resolve_path(state.filepath)) == 1)
        state.on_reject("Rejected by user")
    end

    vim.keymap.set("n", "<CR>", accept, { buffer = prop_buf, nowait = true })
    vim.keymap.set("n", "q", reject, { buffer = prop_buf, nowait = true })
    vim.keymap.set("n", "<CR>", accept, { buffer = orig_buf, nowait = true })
    vim.keymap.set("n", "q", reject, { buffer = orig_buf, nowait = true })

    -- Autocmd for manual close
    state.autocmd_id = vim.api.nvim_create_autocmd("BufWinLeave", {
        buffer = prop_buf,
        once = true,
        callback = function()
            vim.schedule(function()
                if diff_state == state then
                    close_diff_view(state, vim.fn.filereadable(resolve_path(state.filepath)) == 1)
                    state.on_reject("Rejected by user")
                end
            end)
        end,
    })

    diff_state = state
end

M.register_async("edit_file", {
    name = "edit_file",
    description = "Replace file contents. Shows diff for user approval before writing. User presses <CR> to accept, q to reject.",
    input_schema = {
        type = "object",
        properties = {
            path = { type = "string", description = "File path (absolute or relative to cwd)" },
            content = { type = "string", description = "Full new file content" },
        },
        required = { "path", "content" },
    },
},
-- sync executor (blocking - not recommended)
function(input)
    return { success = false, error = "edit_file requires async execution" }
end,
-- async executor
function(input, callback)
    if not input.path then
        callback({ success = false, error = "Missing path" })
        return
    end
    if not input.content then
        callback({ success = false, error = "Missing content" })
        return
    end

    local path = resolve_path(input.path)
    local proposed_lines = vim.split(input.content, "\n", { plain = true })

    -- Read original (empty if new file)
    local original_lines = {}
    if vim.fn.filereadable(path) == 1 then
        original_lines = vim.fn.readfile(path)
    end

    vim.schedule(function()
        open_diff_view(
            original_lines,
            proposed_lines,
            input.path,
            function() callback({ success = true, message = "File written: " .. input.path }) end,
            function(reason) callback({ success = false, error = reason or "Edit rejected" }) end
        )
    end)
end)

-- read_file: read file contents
M.register("read_file", {
    name = "read_file",
    description = "Read contents of a file. If follow_agent is enabled, the file will be opened in neovim so the user can see it.",
    input_schema = {
        type = "object",
        properties = {
            path = {
                type = "string",
                description = "Path to file (absolute or relative to cwd)",
            },
            start_line = {
                type = "number",
                description = "Start line (1-indexed). Omit to read from beginning.",
            },
            end_line = {
                type = "number",
                description = "End line (1-indexed, inclusive). Omit to read to end.",
            },
        },
        required = { "path" },
    },
}, function(input)
    if not input.path then
        return { success = false, error = "Missing file path" }
    end

    local path = resolve_path(input.path)

    if vim.fn.filereadable(path) ~= 1 then
        return { success = false, error = "File not found: " .. path }
    end

    -- Follow agent: open file in buffer (without stealing focus)
    if M.config.follow_agent then
        vim.schedule(function()
            local current_win = vim.api.nvim_get_current_win()
            local target_win = find_editor_window()
            if target_win then
                vim.api.nvim_win_call(target_win, function()
                    vim.cmd("edit " .. vim.fn.fnameescape(path))
                    if input.start_line then
                        vim.api.nvim_win_set_cursor(0, { input.start_line, 0 })
                    end
                end)
                vim.api.nvim_set_current_win(current_win)
            end
        end)
    end

    local lines = vim.fn.readfile(path)

    local start_line = input.start_line or 1
    local end_line = input.end_line or #lines

    -- Clamp bounds
    start_line = math.max(1, start_line)
    end_line = math.min(#lines, end_line)

    local selected = {}
    for i = start_line, end_line do
        table.insert(selected, string.format("%d: %s", i, lines[i]))
    end

    local content = table.concat(selected, "\n")
    local msg = string.format("File: %s (lines %d-%d)\n%s", path, start_line, end_line, content)

    return { success = true, message = msg }
end)

return M
