require("options")
require("plugins")
require("keymaps")
require("commands")
require("floatterm")
require("ai").setup()

local function read_kimi_creds()
	local creds = {}
	local path = vim.fn.expand("~/.kimi-creds")
	local ok, lines = pcall(vim.fn.readfile, path)
	if ok then
		for _, line in ipairs(lines) do
			local key, val = line:match("^([%w_]+)=(.+)$")
			if key and val then creds[key] = val end
		end
	end
	return creds
end

local kimi_creds = read_kimi_creds()
require("chat_sidebar").setup({
	base_url = kimi_creds.ANTHROPIC_BASE_URL .. "v1/messages",
	api_key = kimi_creds.ANTHROPIC_API_KEY,
	follow_agent = true,
})

