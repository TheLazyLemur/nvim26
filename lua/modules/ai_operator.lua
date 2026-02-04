-- ai_operator.lua - g= operator for AI-assisted code transformation
-- Treats AI as a composable text filter, similar to Unix filters like grep/sed
--
-- Modes:
--   Fill: Auto-fill placeholders (_, TODO, pass, etc.) - auto-accepts valid responses
--   Transform: Review-gated changes via scratch buffer

local M = {}

-- Lazy-load dependencies to avoid errors during testing
local function get_api()
    return require("neogent.api")
end

local function get_tools()
    return require("neogent.tools")
end

-- Configuration
local CONFIG = {
    timeout_ms = 60000,  -- 60 second timeout
    debug = true,        -- Enable debug logging
    log_file = vim.fn.stdpath("cache") .. "/ai_operator.log",
    max_tool_iterations = 10,  -- Max tool calls before forcing response
    read_only_tools = {        -- Tools the agent can execute
        "read_file",
        "search_files",
        "list_files",
        "document_symbols",
        "workspace_symbols",
    },
}

--- Log a debug message
---@param msg string
---@param data any|nil optional data to include
local function log(msg, data)
    if not CONFIG.debug then return end

    local timestamp = os.date("%H:%M:%S")
    local line = string.format("[%s] %s", timestamp, msg)
    if data ~= nil then
        line = line .. " | " .. vim.inspect(data)
    end

    -- Append to log file
    local f = io.open(CONFIG.log_file, "a")
    if f then
        f:write(line .. "\n")
        f:close()
    end
end

--- Clear the log file
function M.clear_log()
    local f = io.open(CONFIG.log_file, "w")
    if f then f:close() end
    vim.notify("Log cleared: " .. CONFIG.log_file, vim.log.levels.INFO)
end

--- Open the log file in a buffer
function M.show_log()
    vim.cmd("split " .. CONFIG.log_file)
end

-- Unique separators for scratch buffer sections
local SEPARATORS = {
    TARGET = "──────────────────── TARGET ────────────────────",
    RESPONSE = "──────────────────── AI RESPONSE ────────────────────",
}

-- State management
local state = {
    scratch_buf = nil,
    scratch_win = nil,
    source_buf = nil,
    target_range = nil,  -- { start_line, end_line }
    mode = nil,          -- "fill" or "transform"
    current_job = nil,
    ns_id = nil,         -- namespace for extmarks
    tool_registered = false,
    timeout_timer = nil,
    got_response = false,
    -- Tracked positions (0-indexed line numbers for nvim_buf_* APIs)
    response_start_line = nil,  -- Line where AI response begins
    original_code = nil,        -- Original target code for diff
}

-- Tool schema for structured code output
local REPLACE_SELECTION_TOOL = {
    name = "replace_selection",
    description = "Replace the selected code with new code. You MUST use this tool to output your response.",
    input_schema = {
        type = "object",
        properties = {
            code = {
                type = "string",
                description = "The replacement code. Must be valid code matching the file's language. Do not include markdown formatting.",
            },
        },
        required = { "code" },
    },
}

--- Register the replace_selection tool if not already registered
local function ensure_tool_registered()
    if state.tool_registered then return end

    local tools = get_tools()
    tools.register("replace_selection", REPLACE_SELECTION_TOOL, function(input)
        -- This executor is never called - we handle the tool response directly
        return { success = true, message = "Code received" }
    end)
    state.tool_registered = true
end

--- Clear any pending timeout
local function clear_timeout()
    if state.timeout_timer then
        vim.fn.timer_stop(state.timeout_timer)
        state.timeout_timer = nil
    end
end

--- Start timeout timer
---@param on_timeout function callback when timeout occurs
local function start_timeout(on_timeout)
    clear_timeout()
    state.got_response = false
    state.timeout_timer = vim.fn.timer_start(CONFIG.timeout_ms, function()
        if not state.got_response then
            vim.schedule(function()
                on_timeout()
            end)
        end
    end)
end

--- Mark that we received a response (cancels timeout)
local function mark_response_received()
    state.got_response = true
    clear_timeout()
end

--- Check if a tool is a read-only exploration tool
---@param name string tool name
---@return boolean
local function is_read_only_tool(name)
    for _, allowed in ipairs(CONFIG.read_only_tools) do
        if name == allowed then
            return true
        end
    end
    return false
end

--- Send request with agentic tool execution loop
--- Executes read-only tools and continues until we get replace_selection or max iterations
---@param messages table[] conversation messages
---@param on_chunk function called with text chunks during streaming
---@param on_code function(code) called when we get the final code
---@param on_error function(err) called on error
local function agentic_send(messages, on_chunk, on_code, on_error)
    local api = get_api()
    local tools = get_tools()
    local iteration = 0
    local conversation = vim.deepcopy(messages)

    local function do_send()
        iteration = iteration + 1
        log("agentic_send iteration " .. iteration)

        if iteration > CONFIG.max_tool_iterations then
            log("max iterations reached, giving up")
            on_error("Max tool iterations reached without getting code")
            return
        end

        state.current_job = api.send(
            conversation,
            on_chunk,
            function(blocks)  -- on_done
                log("agentic iteration " .. iteration .. " got blocks", #blocks)

                -- Check for final code output
                for _, block in ipairs(blocks) do
                    if block.type == "tool_use" then
                        if block.name == "replace_selection" then
                            local code = ""
                            if type(block.input) == "table" and block.input.code then
                                code = block.input.code
                            end
                            log("got replace_selection, code length", #code)
                            on_code(code)
                            return
                        elseif block.name == "replace_lines" then
                            local code = ""
                            if type(block.input) == "table" and block.input.text then
                                code = block.input.text
                            end
                            log("got replace_lines, code length", #code)
                            on_code(code)
                            return
                        end
                    end
                end

                -- Check for read-only tool calls to execute
                local tool_results = {}
                local has_tool_calls = false

                for _, block in ipairs(blocks) do
                    if block.type == "tool_use" and is_read_only_tool(block.name) then
                        has_tool_calls = true
                        log("executing tool", { name = block.name, input = block.input })

                        -- Execute the tool synchronously
                        local result = tools.execute(block.name, block.input)
                        log("tool result", { success = result.success, message_len = result.message and #result.message })

                        table.insert(tool_results, {
                            type = "tool_result",
                            tool_use_id = block.id,
                            content = result.message or result.error or "No output",
                        })
                    end
                end

                if has_tool_calls then
                    -- Add assistant message with the tool uses
                    local assistant_content = {}
                    for _, block in ipairs(blocks) do
                        if block.type == "text" then
                            table.insert(assistant_content, { type = "text", text = block.text })
                        elseif block.type == "tool_use" then
                            table.insert(assistant_content, {
                                type = "tool_use",
                                id = block.id,
                                name = block.name,
                                input = block.input,
                            })
                        end
                    end
                    table.insert(conversation, { role = "assistant", content = assistant_content })

                    -- Add tool results as user message
                    table.insert(conversation, { role = "user", content = tool_results })

                    -- Continue the loop
                    vim.schedule(do_send)
                else
                    -- No tool calls and no replace_selection - extract from text
                    log("no tool calls, falling back to text extraction")
                    local code = ""
                    for _, block in ipairs(blocks) do
                        if block.type == "text" and block.text then
                            code = code .. block.text
                        end
                    end
                    -- Strip markdown fences
                    code = code:gsub("^```[^\n]*\n", ""):gsub("\n```%s*$", "")
                    on_code(code)
                end
            end,
            on_error
        )
    end

    do_send()
end

-- Placeholder patterns for fill mode detection
local PLACEHOLDER_PATTERNS = {
    "^%s*_%s*$",                    -- Single underscore
    "^%s*TODO%s*$",                 -- TODO alone
    "^%s*pass%s*$",                 -- Python pass
    "^%s*%.%.%.%s*$",               -- Ellipsis
    "^%s*unimplemented!%(%)[;]?%s*$", -- Rust unimplemented!()
    "^%s*todo!%(%)[;]?%s*$",        -- Rust todo!()
    "^%s*[#/%-]+%s*TODO%s*$",       -- Comment TODO (# TODO, // TODO, -- TODO)
    "^%s*raise%s+NotImplementedError%s*$", -- Python NotImplementedError
}

--- Check if a single line is a placeholder
---@param line string
---@return boolean
function M._is_placeholder(line)
    for _, pattern in ipairs(PLACEHOLDER_PATTERNS) do
        if line:match(pattern) then
            return true
        end
    end
    return false
end

--- Detect the mode based on content
---@param lines string[]
---@return "fill"|"transform"
function M._detect_mode(lines)
    -- Check if all non-empty lines are placeholders
    local has_content = false
    for _, line in ipairs(lines) do
        if line:match("%S") then  -- Has non-whitespace
            has_content = true
            if not M._is_placeholder(line) then
                return "transform"
            end
        end
    end

    -- If we have placeholder content, it's fill mode
    if has_content then
        return "fill"
    end

    -- Empty selection defaults to transform
    return "transform"
end

--- Search upward for AGENT.md from current file
---@return string|nil path to AGENT.md or nil if not found
function M._find_agent_md()
    local path = vim.fn.expand("%:p:h")

    while path ~= "/" and path ~= "" do
        local agent = path .. "/AGENT.md"
        if vim.fn.filereadable(agent) == 1 then
            return agent
        end
        path = vim.fn.fnamemodify(path, ":h")
    end

    -- Fallback to global AGENT.md
    local global = vim.fn.expand("~/.config/nvim/AGENT.md")
    if vim.fn.filereadable(global) == 1 then
        return global
    end

    return nil
end

--- Build context range around target
---@param bufnr number
---@param start_line number 1-indexed
---@param end_line number 1-indexed
---@param context_lines number lines of context to include
---@return table { before_start, before_end, after_start, after_end }
function M._build_context(bufnr, start_line, end_line, context_lines)
    context_lines = context_lines or 10
    local total_lines = vim.api.nvim_buf_line_count and vim.api.nvim_buf_line_count(bufnr) or 1000

    return {
        before_start = math.max(1, start_line - context_lines),
        before_end = start_line - 1,
        after_start = end_line + 1,
        after_end = math.min(total_lines, end_line + context_lines),
    }
end

--- Read file contents
---@param path string
---@return string|nil content
local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

--- Get buffer lines as string
---@param bufnr number
---@param start_line number 0-indexed
---@param end_line number 0-indexed, exclusive
---@return string
local function get_lines_string(bufnr, start_line, end_line)
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
    return table.concat(lines, "\n")
end

--- Build the system prompt for constrained write
---@param filepath string
---@param start_line number
---@param end_line number
---@param agent_context string|nil
---@return string
local function build_system_prompt(filepath, start_line, end_line, agent_context, mode)
    local base = [[You are a code completion agent.

## Available Tools
- read_file: Read file contents to understand types, interfaces, structs, or patterns
- search_files: Search for patterns, type definitions, or usages across codebase
- list_files: List files in directories to find relevant modules
- document_symbols: Get symbols (functions, types, fields) in a file
- workspace_symbols: Search for type/function definitions by name
- replace_selection: OUTPUT YOUR FINAL CODE (required)

]]

    local mode_instructions
    if mode == "fill" then
        mode_instructions = [[## Mode: FILL
You are filling in a placeholder (TODO, pass, unimplemented, etc.) with real implementation.

### Workflow
1. Examine the function/method signature and surrounding code
2. If types or dependencies are unclear, USE TOOLS to explore:
   - Read type definitions to understand fields and methods
   - Search for similar implementations to follow patterns
   - Check how this code is used elsewhere
3. Generate the implementation using replace_selection

### Fill Rules
- Implement the COMPLETE functionality - not just a stub
- Include proper return statements matching the return type
- Handle edge cases appropriately
- Follow patterns from similar code in the codebase
]]
    else
        mode_instructions = [[## Mode: TRANSFORM
You are transforming/refactoring existing code based on the user's instruction.

### Workflow
1. Understand the user's instruction and the existing code
2. If you need more context, USE TOOLS to explore:
   - Read related files to understand dependencies
   - Search for usages to avoid breaking changes
   - Check type definitions if modifying signatures
3. Generate the transformed code using replace_selection

### Transform Rules
- Follow the user's instruction precisely
- Preserve functionality unless explicitly asked to change it
- Maintain code style consistency with the codebase
]]
    end

    local output_rules = [[
## Output Rules (CRITICAL)
- You MUST call replace_selection to output your final code
- The code parameter contains ONLY the replacement - not surrounding context
- No markdown formatting or code fences in the tool input
- Match the indentation style of the surrounding code
- Do NOT add or modify imports unless explicitly asked - focus only on the target code
- Do NOT include package/module declarations unless explicitly asked
- Assume all necessary imports already exist

Target file: %s
Target lines: %d-%d
]]

    local prompt = base .. mode_instructions .. string.format(output_rules, filepath, start_line, end_line)

    prompt = string.format(prompt, filepath, start_line, end_line)

    if agent_context then
        prompt = prompt .. "\n\nProject context:\n" .. agent_context
    end

    return prompt
end

--- Build messages for API call
---@param target_code string the code to transform
---@param instruction string|nil user instruction (for transform mode)
---@param context_before string|nil code before target
---@param context_after string|nil code after target
---@param mode string "fill" or "transform"
---@return table[] messages
local function build_messages(target_code, instruction, context_before, context_after, mode)
    local messages = {}

    local user_content = ""

    if context_before and context_before ~= "" then
        user_content = user_content .. "Code before target:\n```\n" .. context_before .. "\n```\n\n"
    end

    user_content = user_content .. "Target code to " .. (mode == "fill" and "fill in" or "transform") .. ":\n```\n" .. target_code .. "\n```\n"

    if context_after and context_after ~= "" then
        user_content = user_content .. "\nCode after target:\n```\n" .. context_after .. "\n```\n"
    end

    if mode == "fill" then
        user_content = user_content .. "\nFill in the placeholder with appropriate implementation."
    elseif instruction and instruction ~= "" then
        user_content = user_content .. "\nInstruction: " .. instruction
    else
        user_content = user_content .. "\nImprove or refactor this code."
    end

    user_content = user_content .. "\n\nUse the replace_selection tool to output your code."

    table.insert(messages, { role = "user", content = user_content })

    return messages
end

--- Extract code from API response blocks
---@param blocks table[] content blocks from API
---@return string code
local function extract_code(blocks)
    -- First, look for our replace_selection tool
    for _, block in ipairs(blocks) do
        if block.type == "tool_use" and block.name == "replace_selection" then
            if type(block.input) == "table" and block.input.code then
                return block.input.code
            elseif type(block.input) == "string" then
                local ok, parsed = pcall(vim.json.decode, block.input)
                if ok and parsed.code then
                    return parsed.code
                end
            end
        end
    end

    -- Also check for neogent's replace_lines tool (AI might use this instead)
    for _, block in ipairs(blocks) do
        if block.type == "tool_use" and block.name == "replace_lines" then
            if type(block.input) == "table" and block.input.text then
                return block.input.text
            elseif type(block.input) == "string" then
                local ok, parsed = pcall(vim.json.decode, block.input)
                if ok and parsed.text then
                    return parsed.text
                end
            end
        end
    end

    -- Fallback to text blocks if no tool use found
    local code_parts = {}
    for _, block in ipairs(blocks) do
        if block.type == "text" and block.text then
            -- Strip markdown code fences if present
            local text = block.text
            text = text:gsub("^```[^\n]*\n", "")  -- Remove opening fence
            text = text:gsub("\n```%s*$", "")      -- Remove closing fence
            table.insert(code_parts, text)
        end
    end
    return table.concat(code_parts, "")
end

--- Replace lines in buffer atomically (single undo)
---@param bufnr number
---@param start_line number 1-indexed
---@param end_line number 1-indexed
---@param new_lines string[]
local function replace_range(bufnr, start_line, end_line, new_lines)
    -- Use undojoin to make it a single undo operation
    vim.cmd("silent! undojoin")
    vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, new_lines)
end

--- Show spinner on target line
---@param bufnr number
---@param line number 1-indexed
local function show_spinner(bufnr, line)
    state.ns_id = state.ns_id or vim.api.nvim_create_namespace("ai_operator")
    vim.api.nvim_buf_set_extmark(bufnr, state.ns_id, line - 1, 0, {
        virt_text = {{ "⚙ generating...", "Comment" }},
        virt_text_pos = "eol",
    })
end

--- Clear spinner
---@param bufnr number
local function clear_spinner(bufnr)
    if state.ns_id then
        vim.api.nvim_buf_clear_namespace(bufnr, state.ns_id, 0, -1)
    end
end

--- Close scratch buffer and window
local function close_scratch()
    if state.scratch_win and vim.api.nvim_win_is_valid(state.scratch_win) then
        vim.api.nvim_win_close(state.scratch_win, true)
    end
    if state.scratch_buf and vim.api.nvim_buf_is_valid(state.scratch_buf) then
        vim.api.nvim_buf_delete(state.scratch_buf, { force = true })
    end
    state.scratch_buf = nil
    state.scratch_win = nil
end

--- Apply response from scratch buffer to source
local function apply_response()
    if not state.scratch_buf or not state.source_buf or not state.target_range then
        vim.notify("No pending changes to apply", vim.log.levels.WARN)
        return
    end

    if not state.response_start_line then
        vim.notify("No response found", vim.log.levels.ERROR)
        return
    end

    -- Get response lines directly using tracked position (0-indexed)
    local response_lines = vim.api.nvim_buf_get_lines(
        state.scratch_buf,
        state.response_start_line,
        -1,
        false
    )

    -- Trim trailing empty lines
    while #response_lines > 0 and response_lines[#response_lines]:match("^%s*$") do
        table.remove(response_lines)
    end

    -- Apply to source buffer
    replace_range(state.source_buf, state.target_range.start_line, state.target_range.end_line, response_lines)

    vim.notify("Changes applied", vim.log.levels.INFO)
    close_scratch()
end

--- Open diff view comparing original and response
local function open_diff()
    if not state.scratch_buf or not state.source_buf or not state.target_range then
        vim.notify("No changes to diff", vim.log.levels.WARN)
        return
    end

    if not state.response_start_line then
        vim.notify("No response to diff", vim.log.levels.WARN)
        return
    end

    -- Get original from state (stored when we opened scratch buffer)
    local original = state.original_code or {}

    -- Get response using tracked position (0-indexed)
    local response = vim.api.nvim_buf_get_lines(
        state.scratch_buf,
        state.response_start_line,
        -1,
        false
    )

    -- Create temp buffers for diff
    local orig_buf = vim.api.nvim_create_buf(false, true)
    local resp_buf = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_lines(orig_buf, 0, -1, false, original)
    vim.api.nvim_buf_set_lines(resp_buf, 0, -1, false, response)

    vim.bo[orig_buf].filetype = vim.bo[state.source_buf].filetype
    vim.bo[resp_buf].filetype = vim.bo[state.source_buf].filetype

    -- Open diff view
    vim.cmd("tabnew")
    local diff_tab = vim.api.nvim_get_current_tabpage()
    vim.api.nvim_win_set_buf(0, orig_buf)
    vim.cmd("diffthis")
    vim.cmd("vsplit")
    vim.api.nvim_win_set_buf(0, resp_buf)
    vim.cmd("diffthis")

    vim.bo[orig_buf].bufhidden = "wipe"
    vim.bo[resp_buf].bufhidden = "wipe"

    -- Close diff with q
    local function close_diff()
        vim.cmd("tabclose")
    end
    vim.keymap.set("n", "q", close_diff, { buffer = orig_buf, silent = true })
    vim.keymap.set("n", "q", close_diff, { buffer = resp_buf, silent = true })
end

--- Submit instruction to API (called from scratch buffer)
local function submit_to_api()
    if not state.scratch_buf or not state.source_buf or not state.target_range then
        vim.notify("Invalid state for API submission", vim.log.levels.ERROR)
        return
    end

    ensure_tool_registered()
    local api = get_api()

    -- Get instruction from scratch buffer (first section before separator)
    local scratch_lines = vim.api.nvim_buf_get_lines(state.scratch_buf, 0, -1, false)
    local instruction_lines = {}
    for _, line in ipairs(scratch_lines) do
        if line:match("^─+") or line:match("^%-%-%-") then
            break
        end
        table.insert(instruction_lines, line)
    end
    local instruction = table.concat(instruction_lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")

    -- Get target code
    local target_lines = vim.api.nvim_buf_get_lines(
        state.source_buf,
        state.target_range.start_line - 1,
        state.target_range.end_line,
        false
    )
    local target_code = table.concat(target_lines, "\n")

    -- Get context
    local ctx = M._build_context(state.source_buf, state.target_range.start_line, state.target_range.end_line, 10)
    local context_before = get_lines_string(state.source_buf, ctx.before_start - 1, ctx.before_end)
    local context_after = get_lines_string(state.source_buf, ctx.after_start - 1, ctx.after_end)

    -- Build messages
    local messages = build_messages(target_code, instruction, context_before, context_after, "transform")

    -- Get AGENT.md context
    local agent_path = M._find_agent_md()
    local agent_context = agent_path and read_file(agent_path)

    -- Configure API with constrained system prompt
    local filepath = vim.fn.expand("#" .. state.source_buf .. ":p")
    local original_config = api.get_config()
    api.configure({
        system_prompt = build_system_prompt(
            filepath,
            state.target_range.start_line,
            state.target_range.end_line,
            agent_context,
            "transform"
        )
    })

    -- Add separator and response area to scratch buffer
    local sep_line = SEPARATORS.RESPONSE
    local line_count_before = vim.api.nvim_buf_line_count(state.scratch_buf)
    vim.api.nvim_buf_set_lines(state.scratch_buf, -1, -1, false, { "", sep_line, "" })
    -- Track where response content starts (0-indexed): after "", sep_line, ""
    state.response_start_line = line_count_before + 2  -- Points to the empty line after separator

    -- Start timeout
    start_timeout(function()
        if state.current_job then
            api.cancel(state.current_job)
            state.current_job = nil
        end
        api.configure({ system_prompt = original_config.system_prompt })
        vim.notify("Request timed out after " .. (CONFIG.timeout_ms / 1000) .. "s", vim.log.levels.ERROR)
    end)

    log("=== TRANSFORM MODE START ===")
    log("instruction", instruction)

    -- Use agentic send with tool execution loop
    agentic_send(
        messages,
        function(text)  -- on_chunk
            mark_response_received()
            -- Could stream text to scratch buffer here if desired
        end,
        function(code)  -- on_code (final code received)
            mark_response_received()
            api.configure({ system_prompt = original_config.system_prompt })

            log("transform on_code received", #code)

            -- Display code in scratch buffer using tracked position
            if code and code ~= "" and state.scratch_buf and vim.api.nvim_buf_is_valid(state.scratch_buf) and state.response_start_line then
                local code_lines = vim.split(code, "\n", { plain = true })
                vim.api.nvim_buf_set_lines(state.scratch_buf, state.response_start_line, -1, false, code_lines)
            end

            vim.notify("Response complete. Press <C-CR> to apply, <C-d> for diff, q to cancel", vim.log.levels.INFO)
        end,
        function(err)  -- on_error
            mark_response_received()
            api.configure({ system_prompt = original_config.system_prompt })
            log("transform on_error", err)
            vim.notify("API error: " .. tostring(err), vim.log.levels.ERROR)
        end
    )

    vim.notify("Sending to API...", vim.log.levels.INFO)
end

--- Open scratch buffer for transform mode
---@param source_buf number
---@param start_line number 1-indexed
---@param end_line number 1-indexed
local function open_scratch(source_buf, start_line, end_line)
    -- Store state
    state.source_buf = source_buf
    state.target_range = { start_line = start_line, end_line = end_line }
    state.mode = "transform"

    -- Create scratch buffer
    local buf = vim.api.nvim_create_buf(false, true)
    state.scratch_buf = buf

    -- Set buffer name (required for BufWriteCmd with acwrite)
    vim.api.nvim_buf_set_name(buf, "[AI Operator]")

    vim.bo[buf].buftype = "acwrite"
    vim.bo[buf].filetype = vim.bo[source_buf].filetype
    vim.bo[buf].bufhidden = "wipe"

    -- Open horizontal split below
    vim.cmd("botright split")
    local win = vim.api.nvim_get_current_win()
    state.scratch_win = win

    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_win_set_height(win, 15)

    -- Get target code for display and store for diff
    local target_lines = vim.api.nvim_buf_get_lines(source_buf, start_line - 1, end_line, false)
    state.original_code = target_lines
    state.response_start_line = nil  -- Reset until we get a response

    -- Populate buffer with instruction area and folded context
    local initial_lines = {
        "-- Type your instruction below, then :w to send to AI",
        "-- Press q to cancel, <C-CR> to apply response, <C-d> for diff",
        "",
        "",  -- User types instruction here
        "",
        SEPARATORS.TARGET,
    }

    -- Add target code (folded)
    for _, line in ipairs(target_lines) do
        table.insert(initial_lines, line)
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, initial_lines)

    -- Position cursor on instruction line
    vim.api.nvim_win_set_cursor(win, { 4, 0 })

    -- Set up keymaps
    local opts = { buffer = buf, silent = true }
    vim.keymap.set("n", "q", close_scratch, opts)
    vim.keymap.set("n", "<C-CR>", apply_response, opts)
    vim.keymap.set("n", "<C-d>", open_diff, opts)

    -- BufWriteCmd triggers API call
    vim.api.nvim_create_autocmd("BufWriteCmd", {
        buffer = buf,
        callback = function()
            submit_to_api()
            vim.bo[buf].modified = false
        end,
    })

    -- Enter insert mode
    vim.cmd("startinsert")
end

--- Handle fill mode (auto-accept for simple placeholders)
---@param source_buf number
---@param start_line number 1-indexed
---@param end_line number 1-indexed
local function fill_mode(source_buf, start_line, end_line)
    log("=== FILL MODE START ===")
    ensure_tool_registered()
    local api = get_api()

    state.source_buf = source_buf
    state.target_range = { start_line = start_line, end_line = end_line }
    state.mode = "fill"

    -- Show spinner
    show_spinner(source_buf, start_line)

    -- Get target code
    local target_lines = vim.api.nvim_buf_get_lines(source_buf, start_line - 1, end_line, false)
    local target_code = table.concat(target_lines, "\n")
    log("target code", target_code)

    -- Get context
    local ctx = M._build_context(source_buf, start_line, end_line, 15)
    local context_before = get_lines_string(source_buf, ctx.before_start - 1, ctx.before_end)
    local context_after = get_lines_string(source_buf, ctx.after_start - 1, ctx.after_end)
    log("context before (lines)", ctx.before_start .. "-" .. ctx.before_end)
    log("context after (lines)", ctx.after_start .. "-" .. ctx.after_end)

    -- Build messages
    local messages = build_messages(target_code, nil, context_before, context_after, "fill")
    log("user message", messages[1] and messages[1].content)

    -- Get AGENT.md context
    local agent_path = M._find_agent_md()
    local agent_context = agent_path and read_file(agent_path)

    -- Configure API
    local filepath = vim.fn.expand("#" .. source_buf .. ":p")
    local api = get_api()
    local original_config = api.get_config()
    api.configure({
        system_prompt = build_system_prompt(filepath, start_line, end_line, agent_context, "fill")
    })

    -- Start timeout
    start_timeout(function()
        if state.current_job then
            api.cancel(state.current_job)
            state.current_job = nil
        end
        api.configure({ system_prompt = original_config.system_prompt })
        clear_spinner(source_buf)
        vim.notify("Fill request timed out after " .. (CONFIG.timeout_ms / 1000) .. "s", vim.log.levels.ERROR)
    end)

    -- Use agentic send with tool execution loop
    agentic_send(
        messages,
        function(text)  -- on_chunk
            mark_response_received()
            -- Could show streaming text somewhere if desired
        end,
        function(code)  -- on_code (final code received)
            mark_response_received()
            api.configure({ system_prompt = original_config.system_prompt })
            clear_spinner(source_buf)

            log("fill on_code received", #code)

            -- Strip markdown fences if present
            code = code:gsub("^```[^\n]*\n", ""):gsub("\n```%s*$", "")
            -- Trim leading/trailing whitespace-only lines but preserve internal structure
            code = code:gsub("^%s*\n", ""):gsub("\n%s*$", "")

            log("final code length after cleanup", #code)

            -- Validate we got actual code
            if code == "" or code:match("^%s*$") then
                log("FAILED: empty response")
                vim.notify("Fill failed: empty response. Opening editor.", vim.log.levels.WARN)
                open_scratch(source_buf, start_line, end_line)
                return
            end

            local new_lines = vim.split(code, "\n", { plain = true })
            log("applying lines", #new_lines)

            -- Auto-accept: replace inline
            replace_range(source_buf, start_line, end_line, new_lines)
            vim.notify("Fill complete", vim.log.levels.INFO)
        end,
        function(err)  -- on_error
            mark_response_received()
            api.configure({ system_prompt = original_config.system_prompt })
            clear_spinner(source_buf)
            log("fill on_error", err)
            vim.notify("Fill error: " .. tostring(err), vim.log.levels.ERROR)

            -- Fallback to scratch buffer on error
            open_scratch(source_buf, start_line, end_line)
        end
    )

    log("fill request sent", { file = filepath, lines = start_line .. "-" .. end_line })
end

--- Main operator function called by g@
---@param motion_type string "line", "char", or "block"
function M.operator(motion_type)
    local start_line, end_line

    if motion_type == "line" then
        start_line = vim.fn.line("'[")
        end_line = vim.fn.line("']")
    elseif motion_type == "char" then
        start_line = vim.fn.line("'[")
        end_line = vim.fn.line("']")
    elseif motion_type == "block" then
        start_line = vim.fn.line("'[")
        end_line = vim.fn.line("']")
    else
        -- Visual mode
        start_line = vim.fn.line("'<")
        end_line = vim.fn.line("'>")
    end

    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

    local mode = M._detect_mode(lines)

    if mode == "fill" then
        fill_mode(bufnr, start_line, end_line)
    else
        open_scratch(bufnr, start_line, end_line)
    end
end

--- Visual mode operator
function M.visual_operator()
    local start_line = vim.fn.line("'<")
    local end_line = vim.fn.line("'>")

    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

    local mode = M._detect_mode(lines)

    if mode == "fill" then
        fill_mode(bufnr, start_line, end_line)
    else
        open_scratch(bufnr, start_line, end_line)
    end
end

--- Cancel current operation
function M.cancel()
    if state.current_job then
        local api = get_api()
        api.cancel(state.current_job)
        state.current_job = nil
    end

    if state.source_buf then
        clear_spinner(state.source_buf)
    end

    close_scratch()
    vim.notify("Operation cancelled", vim.log.levels.INFO)
end

--- Setup keymaps
function M.setup()
    -- Normal mode: g= as operator
    vim.keymap.set("n", "g=", function()
        vim.o.operatorfunc = "v:lua.require'modules.ai_operator'.operator"
        return "g@"
    end, { expr = true, desc = "AI operator" })

    -- Line-wise: g== for current line
    vim.keymap.set("n", "g==", function()
        vim.o.operatorfunc = "v:lua.require'modules.ai_operator'.operator"
        return "g@_"
    end, { expr = true, desc = "AI operator (line)" })

    -- Visual mode: g= on selection
    vim.keymap.set("x", "g=", function()
        -- Exit visual mode first to set '< and '> marks
        vim.cmd("normal! \027")  -- <Esc>
        M.visual_operator()
    end, { desc = "AI operator (visual)" })

    -- Cancel with <C-c> during operation
    vim.keymap.set("n", "<C-c>", function()
        if state.current_job then
            M.cancel()
        else
            -- Default behavior
            vim.cmd("normal! \003")
        end
    end, { desc = "Cancel AI operation" })
end

return M
