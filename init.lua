require("options")
require("plugins")
require("keymaps")
require("commands")
require("floatterm")

local function setup_ai()
    require("ai").setup()

    local function load_credentials(path)
        local creds = {}
        path = vim.fn.expand(path)
        local ok, lines = pcall(vim.fn.readfile, path)
        if ok then
            for _, line in ipairs(lines) do
                local key, val = line:match("^([%w_]+)=(.+)$")
                if key and val then creds[key] = val end
            end
        end
        return creds
    end

    local function load_kimi_creds()
        local path = vim.fn.expand("~/.kimi-creds")
        local creds = load_credentials(path)
        return {
            base_url = creds.ANTHROPIC_BASE_URL .. "v1/messages",
            api_key = creds.ANTHROPIC_API_KEY,
        }
    end

    local function load_glm_creds()
        local path = vim.fn.expand("~/.glm-creds")
        local creds = load_credentials(path)
        return {
            base_url = creds.GLM_BASE_URL,
            api_key = creds.GLM_API_KEY,
        }
    end

    local creds_map = {
        glm = load_glm_creds,
        kimi = load_kimi_creds,
    }

    require("neogent").setup(vim.tbl_extend("force", creds_map.kimi(), {
        follow_agent = false,
        inject_diagnostics = false,
    }))
end

setup_ai()
