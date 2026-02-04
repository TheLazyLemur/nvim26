-- Quick syntax test for tools.lua
package.path = package.path .. ";lua/?.lua;lua/?/init.lua"

-- Clear cache to force reload
package.loaded["chat_sidebar.tools"] = nil
package.loaded["chat_sidebar.ui"] = nil

local ok, err = pcall(function()
    require("chat_sidebar.tools")
end)
if ok then
    print("✓ tools.lua loaded successfully")
    local tools = require("chat_sidebar.tools")
    local tool_list = tools.list()
    table.sort(tool_list)
    print("  Registered tools: " .. table.concat(tool_list, ", "))
else
    print("✗ Error loading tools.lua: " .. tostring(err))
end
