-- ai_operator tests
-- Run with: nvim --headless -u NONE -c "set rtp+=." -c "lua require('modules.ai_operator_test').run()" -c "qa!"

local M = {}

-- Simple test framework
local test_results = { passed = 0, failed = 0, errors = {} }

local function describe(name, fn)
    print("\n" .. name)
    fn()
end

local function it(name, fn)
    local ok, err = pcall(fn)
    if ok then
        test_results.passed = test_results.passed + 1
        print("  ✓ " .. name)
    else
        test_results.failed = test_results.failed + 1
        table.insert(test_results.errors, { name = name, error = err })
        print("  ✗ " .. name)
        print("    " .. tostring(err))
    end
end

local function assert_eq(expected, actual, msg)
    if expected ~= actual then
        error(string.format("%s: expected %s, got %s", msg or "Assertion failed", vim.inspect(expected), vim.inspect(actual)))
    end
end

local function assert_true(val, msg)
    if not val then
        error(msg or "Expected true")
    end
end

local function assert_false(val, msg)
    if val then
        error(msg or "Expected false")
    end
end

-- Mock vim APIs for headless testing
local function setup_mocks()
    -- Ensure vim global exists
    if not vim then
        _G.vim = {}
    end

    -- Mock fn namespace
    vim.fn = vim.fn or {}
    vim.fn.expand = vim.fn.expand or function(str)
        if str == "%:p:h" then return "/tmp/test/project/src" end
        if str == "~/.config/nvim/AGENT.md" then return "/home/user/.config/nvim/AGENT.md" end
        return str
    end
    vim.fn.fnamemodify = vim.fn.fnamemodify or function(path, mod)
        if mod == ":h" then
            return path:match("(.+)/[^/]+$") or "/"
        end
        return path
    end
    vim.fn.filereadable = vim.fn.filereadable or function(path)
        if path == "/tmp/test/project/AGENT.md" then return 1 end
        return 0
    end

    -- Mock api namespace
    vim.api = vim.api or {}
    vim.api.nvim_create_buf = vim.api.nvim_create_buf or function() return 1 end
    vim.api.nvim_buf_get_lines = vim.api.nvim_buf_get_lines or function() return {} end
    vim.api.nvim_buf_set_lines = vim.api.nvim_buf_set_lines or function() end
    vim.api.nvim_create_namespace = vim.api.nvim_create_namespace or function() return 1 end

    -- Mock keymap
    vim.keymap = vim.keymap or {}
    vim.keymap.set = vim.keymap.set or function() end

    -- Mock bo (buffer options)
    vim.bo = vim.bo or setmetatable({}, {
        __index = function() return {} end,
        __newindex = function() end,
    })

    -- Mock o (options)
    vim.o = vim.o or {}

    -- Mock tbl_extend
    vim.tbl_extend = vim.tbl_extend or function(behaviour, ...)
        local result = {}
        for _, tbl in ipairs({...}) do
            for k, v in pairs(tbl) do
                result[k] = v
            end
        end
        return result
    end

    -- Mock inspect
    vim.inspect = vim.inspect or function(val)
        if type(val) == "string" then return '"' .. val .. '"' end
        if type(val) == "table" then return "{...}" end
        return tostring(val)
    end
end

-- Load the module under test
local function load_ai_operator()
    setup_mocks()

    -- Clear cache to force reload with fresh mocks
    package.loaded["modules.ai_operator"] = nil

    -- Mock neogent dependencies to prevent loading errors
    package.loaded["neogent.api"] = {
        send = function() return 1 end,
        configure = function() end,
        get_config = function() return {} end,
        cancel = function() end,
    }
    package.loaded["neogent.tools"] = {
        get_schemas = function() return {} end,
    }

    return require("modules.ai_operator")
end

-- Run all tests
local function run()
    -- Reset results
    test_results = { passed = 0, failed = 0, errors = {} }

    describe("detect_mode", function()
        local ai_op = load_ai_operator()

        it("detects underscore placeholder as fill mode", function()
            assert_eq("fill", ai_op._detect_mode({"_"}))
        end)

        it("detects underscore with whitespace as fill mode", function()
            assert_eq("fill", ai_op._detect_mode({"  _  "}))
        end)

        it("detects TODO placeholder as fill mode", function()
            assert_eq("fill", ai_op._detect_mode({"TODO"}))
        end)

        it("detects pass placeholder as fill mode", function()
            assert_eq("fill", ai_op._detect_mode({"pass"}))
        end)

        it("detects unimplemented!() as fill mode", function()
            assert_eq("fill", ai_op._detect_mode({"unimplemented!()"}))
        end)

        it("detects regular code as transform mode", function()
            assert_eq("transform", ai_op._detect_mode({"local x = 1"}))
        end)

        it("detects multi-line code as transform mode", function()
            assert_eq("transform", ai_op._detect_mode({"function test()", "  return 1", "end"}))
        end)

        it("detects empty lines as transform mode", function()
            assert_eq("transform", ai_op._detect_mode({""}))
        end)
    end)

    describe("find_agent_md", function()
        it("finds AGENT.md in parent directory", function()
            setup_mocks()
            vim.fn.expand = function(str)
                if str == "%:p:h" then return "/tmp/test/project/src" end
                if str:match("~/.config/nvim/AGENT.md") then return "/home/user/.config/nvim/AGENT.md" end
                return str
            end
            vim.fn.filereadable = function(path)
                if path == "/tmp/test/project/AGENT.md" then return 1 end
                return 0
            end
            local ai_op = load_ai_operator()
            local result = ai_op._find_agent_md()
            assert_eq("/tmp/test/project/AGENT.md", result)
        end)

        it("returns nil when no AGENT.md found", function()
            setup_mocks()
            vim.fn.expand = function(str)
                if str == "%:p:h" then return "/tmp/test/project/src" end
                if str:match("~/.config/nvim/AGENT.md") then return "/home/user/.config/nvim/AGENT.md" end
                return str
            end
            vim.fn.filereadable = function() return 0 end
            local ai_op = load_ai_operator()
            local result = ai_op._find_agent_md()
            assert_eq(nil, result)
        end)
    end)

    describe("build_context", function()
        it("captures lines before target", function()
            setup_mocks()
            vim.api.nvim_buf_line_count = function() return 100 end
            local ai_op = load_ai_operator()
            local ctx = ai_op._build_context(1, 5, 10, 3)
            assert_true(ctx.before_start <= 5, "before_start should be <= target start")
        end)

        it("captures lines after target", function()
            setup_mocks()
            vim.api.nvim_buf_line_count = function() return 100 end
            local ai_op = load_ai_operator()
            local ctx = ai_op._build_context(1, 5, 10, 3)
            assert_true(ctx.after_end >= 10, "after_end should be >= target end")
        end)
    end)

    describe("placeholder patterns", function()
        local ai_op = load_ai_operator()

        it("matches Python pass", function()
            assert_true(ai_op._is_placeholder("pass"))
            assert_true(ai_op._is_placeholder("    pass"))
            assert_true(ai_op._is_placeholder("pass  "))
        end)

        it("matches Rust unimplemented", function()
            assert_true(ai_op._is_placeholder("unimplemented!()"))
            assert_true(ai_op._is_placeholder("    unimplemented!()"))
        end)

        it("matches todo!()", function()
            assert_true(ai_op._is_placeholder("todo!()"))
        end)

        it("matches TODO comment style", function()
            assert_true(ai_op._is_placeholder("TODO"))
            assert_true(ai_op._is_placeholder("// TODO"))
            assert_true(ai_op._is_placeholder("# TODO"))
            assert_true(ai_op._is_placeholder("-- TODO"))
        end)

        it("does not match regular code", function()
            assert_false(ai_op._is_placeholder("local x = 1"))
            assert_false(ai_op._is_placeholder("return todo_list"))
            assert_false(ai_op._is_placeholder("pass_through()"))
        end)
    end)

    print("\n" .. string.rep("-", 40))
    print(string.format("Tests: %d passed, %d failed", test_results.passed, test_results.failed))

    if test_results.failed > 0 then
        os.exit(1)
    end
end

-- Export for both direct execution and require
M.run = run
M.describe = describe
M.it = it
M.assert_eq = assert_eq
M.assert_true = assert_true
M.assert_false = assert_false

return M
