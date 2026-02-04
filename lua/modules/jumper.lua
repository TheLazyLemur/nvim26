local M = {}

local line_numbers = {} ---@type table<string, number>

M.config = {
	ui = "snacks", -- "snacks" | "vim" | function
}

local ui_snacks = {}

function ui_snacks.jump_to(files)
	if #files == 0 then
		vim.notify("No jump points available", vim.log.levels.WARN)
		return
	end

	local items = {}
	for i, file in ipairs(files) do
		local display_file = vim.fn.fnamemodify(file, ":~:.")
		local line = line_numbers[file] or 1

		table.insert(items, {
			idx = i,
			file = file,
			text = string.format("%s:%d", display_file, line),
			pos = { line, 0 },
		})
	end

	Snacks.picker.pick({
		items = items,
		format = "file",
		title = "Jump Points",
		confirm = function(picker, item)
			if item then
				picker:close()
				vim.cmd.edit(item.file)
				vim.api.nvim_win_set_cursor(0, { item.pos[1], item.pos[2] })
			end
		end,
	})
end

function ui_snacks.delete_jump_point(files)
	if #files == 0 then
		vim.notify("No jump points available", vim.log.levels.WARN)
		return
	end

	local items = {}
	for i, file in ipairs(files) do
		local display_file = vim.fn.fnamemodify(file, ":~:.")
		local line = line_numbers[file] or 1

		table.insert(items, {
			idx = i,
			file = file,
			text = string.format("%s:%d", display_file, line),
			pos = { line, 0 },
		})
	end

	Snacks.picker.pick({
		items = items,
		format = "file",
		title = "Delete Jump Point",
		confirm = function(picker, item)
			if item then
				picker:close()
				vim.cmd("argdelete " .. vim.fn.fnameescape(item.file))
				line_numbers[item.file] = nil
				vim.notify("Deleted jump point: " .. item.text, vim.log.levels.INFO)
			end
		end,
	})
end

local ui_vim = {}

function ui_vim.jump_to(files)
	if #files == 0 then
		vim.notify("No jump points available", vim.log.levels.WARN)
		return
	end

	local display_items = {}
	for _, file in ipairs(files) do
		local display_file = vim.fn.fnamemodify(file, ":~:.")
		local line = line_numbers[file] or 1
		table.insert(display_items, string.format("%s:%d", display_file, line))
	end

	vim.ui.select(display_items, {
		prompt = "Jump to:",
		format_item = function(item)
			return item
		end,
	}, function(_, idx)
		if idx then
			local file = files[idx]
			local line = line_numbers[file] or 1
			vim.cmd.edit(file)
			vim.api.nvim_win_set_cursor(0, { line, 0 })
		end
	end)
end

function ui_vim.delete_jump_point(files)
	if #files == 0 then
		vim.notify("No jump points available", vim.log.levels.WARN)
		return
	end

	local display_items = {}
	for _, file in ipairs(files) do
		local display_file = vim.fn.fnamemodify(file, ":~:.")
		local line = line_numbers[file] or 1
		table.insert(display_items, string.format("%s:%d", display_file, line))
	end

	vim.ui.select(display_items, {
		prompt = "Delete:",
		format_item = function(item)
			return item
		end,
	}, function(choice, idx)
		if idx then
			local file = files[idx]
			vim.cmd("argdelete " .. vim.fn.fnameescape(file))
			line_numbers[file] = nil
			vim.notify("Deleted '" .. choice .. "' from argument list", vim.log.levels.INFO)
		end
	end)
end

local function get_ui()
	if type(M.config.ui) == "function" then
		return M.config.ui
	elseif M.config.ui == "vim" then
		return ui_vim
	else
		return ui_snacks
	end
end

M.add_jump_point = function()
	local file = vim.api.nvim_buf_get_name(0)
	if file == "" then
		vim.notify("Cannot add jump point: buffer has no name", vim.log.levels.WARN)
		return
	end

	local line = vim.api.nvim_win_get_cursor(0)[1]
	vim.cmd("argadd " .. vim.fn.fnameescape(file))
	vim.cmd("argdedup")
	line_numbers[file] = line
	vim.notify("Added jump point", vim.log.levels.INFO)
end

M.jump_to = function()
	local argv = vim.fn.argv()
	local ui = get_ui()
	ui.jump_to(argv)
end

M.delete_jump_point = function()
	local argv = vim.fn.argv()
	local ui = get_ui()
	ui.delete_jump_point(argv)
end

return M
