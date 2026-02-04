local M = {}

M.setup = function()
    vim.pack.add({
        {
            src = "https://github.com/olimorris/codecompanion.nvim",
        },
        {
            src = "https://github.com/coder/claudecode.nvim",
        },
        {
            src = "https://github.com/sudo-tee/opencode.nvim",
        },
    })

    require("codecompanion").setup({
        interactions = {
            chat = {
                tools = {
                    opts = {
                        -- Auto-load these tools/groups in every chat
                        default_tools = { "full_stack_dev", "get_time", "plan", "task" },
                    },
                    ["plan"] = {
                        callback = {
                            name = "plan",
                            cmds = {
                                ---@param self CodeCompanion.Tools
                                ---@param args table
                                ---@param input any
                                ---@param output_handler function
                                function(tools, action, input, output_handler)
                                    local prompt = action.prompt or ""
                                    local cmd = {
                                        "claude",
                                        "-p",
										"--model", "opus",
                                        "--allowedTools",
                                        "Read,Glob,Grep,WebFetch,WebSearch",
                                        "--system-prompt",
                                        "You are a planning agent. Research and create a detailed implementation plan. You CANNOT modify files. End with a detailed plan.",
                                    }
                                    vim.notify("Plan: " .. prompt:sub(1, 50) .. "...", vim.log.levels.INFO)
                                    -- Pass prompt via stdin to avoid escaping issues
                                    vim.system(cmd, { text = true, stdin = prompt }, function(out)
                                        vim.schedule(function()
                                            local result = out.stdout or ""
                                            local err = out.stderr or ""
                                            if out.code == 0 and result ~= "" then
                                                output_handler({ status = "success", data = result })
                                            else
                                                output_handler({
                                                    status = "error",
                                                    data = err ~= "" and err or "Exit " .. out.code,
                                                })
                                            end
                                        end)
                                    end)
                                end,
                            },
                            schema = {
                                type = "function",
                                ["function"] = {
                                    name = "plan",
                                    description = "Research and create an implementation plan. Read-only - cannot modify files.",
                                    parameters = {
                                        type = "object",
                                        properties = {
                                            prompt = {
                                                type = "string",
                                                description = "The planning task or question to research",
                                            },
                                        },
                                        required = { "prompt" },
                                    },
                                },
                            },
                            output = {
                                success = function(self, tools, cmd, stdout)
                                    local chat = tools.chat
                                    local output = type(stdout) == "table"
                                            and vim.iter(stdout):flatten():join("\n")
                                        or tostring(stdout)
                                    chat:add_tool_output(self, output, "Plan completed")
                                end,
                                error = function(self, tools, cmd, stderr)
                                    local chat = tools.chat
                                    local output = type(stderr) == "table"
                                            and vim.iter(stderr):flatten():join("\n")
                                        or tostring(stderr)
                                    chat:add_tool_output(self, "Plan failed: " .. output)
                                end,
                            },
                        },
                        description = "Planning agent (read-only)",
                    },
                    ["task"] = {
                        callback = {
                            name = "task",
                            cmds = {
                                ---@param self CodeCompanion.Tools
                                ---@param args table
                                ---@param input any
                                ---@param output_handler function
                                function(tools, action, input, output_handler)
                                    local prompt = action.prompt or ""
                                    local cmd = {
                                        "claude",
                                        "-p",
										"--model", "opus",
                                        "--dangerously-skip-permissions",
                                        "--system-prompt",
                                        "You are a task agent. Complete the task, making any necessary file changes. End with a summary of what you accomplished.",
                                    }
                                    vim.notify("Task: " .. prompt:sub(1, 50) .. "...", vim.log.levels.INFO)
                                    -- Pass prompt via stdin to avoid escaping issues
                                    vim.system(cmd, { text = true, stdin = prompt }, function(out)
                                        vim.schedule(function()
                                            local result = out.stdout or ""
                                            local err = out.stderr or ""
                                            if out.code == 0 and result ~= "" then
                                                output_handler({ status = "success", data = result })
                                            else
                                                output_handler({
                                                    status = "error",
                                                    data = err ~= "" and err or "Exit " .. out.code,
                                                })
                                            end
                                        end)
                                    end)
                                end,
                            },
                            schema = {
                                type = "function",
                                ["function"] = {
                                    name = "task",
                                    description = "Execute a task with full file access. Can read, write, and modify files.",
                                    parameters = {
                                        type = "object",
                                        properties = {
                                            prompt = {
                                                type = "string",
                                                description = "The task to execute",
                                            },
                                        },
                                        required = { "prompt" },
                                    },
                                },
                            },
                            output = {
                                success = function(self, tools, cmd, stdout)
                                    local chat = tools.chat
                                    local output = type(stdout) == "table"
                                            and vim.iter(stdout):flatten():join("\n")
                                        or tostring(stdout)
                                    chat:add_tool_output(self, output, "Task completed")
                                end,
                                error = function(self, tools, cmd, stderr)
                                    local chat = tools.chat
                                    local output = type(stderr) == "table"
                                            and vim.iter(stderr):flatten():join("\n")
                                        or tostring(stderr)
                                    chat:add_tool_output(self, "Task failed: " .. output)
                                end,
                            },
                        },
                        description = "Task agent (can modify files)",
                    },
                    ["get_time"] = {
                        callback = {
                            name = "get_time",
                            cmds = {
                                function(self, args)
                                    local format = args.format or "%Y-%m-%d %H:%M:%S"
                                    local time_str = os.date(format)
                                    return {
                                        status = "success",
                                        data = string.format("Current time: %s", time_str),
                                    }
                                end,
                            },
                            schema = {
                                type = "function",
                                ["function"] = {
                                    name = "get_time",
                                    description = "Get the current date and time",
                                    parameters = {
                                        type = "object",
                                        properties = {
                                            format = {
                                                type = "string",
                                                description = "Optional strftime format string (default: %Y-%m-%d %H:%M:%S)",
                                            },
                                        },
                                        required = {},
                                    },
                                },
                            },
                            output = {
                                success = function(self, tools, cmd, stdout)
                                    local chat = tools.chat
                                    local output = vim.iter(stdout):flatten():join("\n")
                                    chat:add_tool_output(self, output, "Retrieved current time")
                                end,
                                error = function(self, tools, cmd, stderr)
                                    local chat = tools.chat
                                    chat:add_tool_output(self, "Failed to get time")
                                end,
                            },
                        },
                        description = "Get current date/time",
                    },
                },
            },
        },
        adapters = {
            http = {
                glm = function()
                    return require("codecompanion.adapters").extend("anthropic", {
                        url = "https://api.z.ai/api/anthropic/v1/messages",
                        env = { auth_token = "GLM_AUTH_TOKEN" },
                        headers = {
                            ["content-type"] = "application/json",
                            ["authorization"] = "Bearer ${auth_token}",
                            ["anthropic-version"] = "2023-06-01",
                        },
                        schema = {
                            model = {
                                default = "glm-4.7",
                                choices = { "glm-4.7", "glm-4.5-air" },
                            },
                            extended_thinking = { default = false },
                            max_tokens = { default = 8192 },
                        },
                        handlers = {
                            setup = function(self)
                                self.headers["x-api-key"] = nil
                                self.headers["anthropic-beta"] = nil
                                if self.opts and self.opts.stream then
                                    self.parameters.stream = true
                                end
                                return true
                            end,
                        },
                    })
                end,
                minimax = function()
                    return require("codecompanion.adapters").extend("anthropic", {
                        url = "https://api.minimax.io/anthropic/v1/messages",
                        env = { auth_token = "MINIMAX_AUTH_TOKEN" },
                        headers = {
                            ["content-type"] = "application/json",
                            ["authorization"] = "Bearer ${auth_token}",
                            ["anthropic-version"] = "2023-06-01",
                        },
                        schema = {
                            model = {
                                default = "MiniMax-M2.1",
                                choices = { "MiniMax-M2.1" },
                            },
                            extended_thinking = { default = false },
                            max_tokens = { default = 8192 },
                        },
                        handlers = {
                            setup = function(self)
                                self.headers["x-api-key"] = nil
                                self.headers["anthropic-beta"] = nil
                                if self.opts and self.opts.stream then
                                    self.parameters.stream = true
                                end
                                return true
                            end,
                        },
                    })
                end,
            },
        },
    })

    require("claudecode").setup()

    require("opencode").setup({
        preferred_picker = "snacks",
        preferred_completion = "blink",
        keymap_prefix = "<leader>o",
    })
end

return M
