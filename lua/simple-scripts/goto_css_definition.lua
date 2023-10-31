local function find_project_root()
	local dir = vim.fn.expand("%:p:h")
	while dir ~= "/" do
		if vim.fn.filereadable(dir .. "/tsconfig.json") == 1 then
			return dir
		end
		dir = vim.fn.fnamemodify(dir, ":h")
	end
	return nil
end

local function read_tsconfig()
	local root_dir = find_project_root()
	if not root_dir then
		return nil, "Could not find project root"
	end

	local f = io.open(root_dir .. "/tsconfig.json", "r")
	if f then
		local content = f:read("*all")
		f:close()
		-- Remove single-line comments
		local sanitized_content = content:gsub("//[^\n]*", "")

		local ok, json_data = pcall(vim.fn.json_decode, sanitized_content)
		if ok then
			return json_data
		else
			return nil, "Could not parse tsconfig.json"
		end
	else
		return nil, "Could not read tsconfig.json"
	end
end

local function find_import_of_object(object_name)
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local import_path = nil
	for _, line in ipairs(lines) do
		-- Handle ES6 import statements
		if line:match("import%s+.*from%s+[\"']") then
			local import_as, import_from = line:match("import%s+(.*)%s+from%s+[\"'](.-)[\"']")
			if import_as and import_from then
				local import_items = vim.split(import_as, ",")
				for _, item in ipairs(import_items) do
					item = item:match("^%s*(.-)%s*$") -- Remove leading/trailing spaces
					if item == object_name then
						import_path = import_from
					end
				end
			end
		-- Handle CommonJS require statements
		elseif line:match("const%s+.*=%s+require%s*%(") then
			local var_name, require_path = line:match("const%s+(.-)%s*=%s*require%s*%([\"'](.-)[\"']%)")
			if var_name and require_path then
				var_name = var_name:match("^%s*(.-)%s*$") -- Remove leading/trailing spaces
				if var_name == object_name then
					import_path = require_path
					break
				end
			end
		end
	end

	local tsconfig = read_tsconfig()
	if tsconfig and tsconfig.compilerOptions and tsconfig.compilerOptions.paths then
		local path = import_path:match("(.*[/\\])")
		print(path)
		for alias, paths in pairs(tsconfig.compilerOptions.paths) do
			print(alias, object_name)
			if string.match(object_name, "^" .. alias:gsub("%*", ".*")) then
				local actual_path = paths[1]:gsub("%*", object_name:match(alias:gsub("%*", "(.*)")))
				print("actual_path", actual_path)
				import_path = actual_path
				break
			end
		end
	end

	return import_path
end

local function find_full_expression(node)
	while node do
		local parent = node:parent()
		if parent and parent:type() == "member_expression" then
			node = parent
		else
			break
		end
	end
	return vim.treesitter.get_node_text(node, 0)
end

local find_class_definition = function()
	local filetype = vim.bo.filetype
	if filetype == "typescriptreact" then
		filetype = "typescript"
	end
	local parser = vim.treesitter.get_parser(0, filetype)
	local tree = parser:parse()[1]
	local root = tree:root()
	local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
	cursor_row = cursor_row - 1

	local object_name, class_name

	local node = root:descendant_for_range(cursor_row, cursor_col, cursor_row, cursor_col + 1)
	if node then
		local content = find_full_expression(node)
		object_name, class_name = content:match("([%w_]+)%s*%.%s*([%w_]+)")
	end

	if object_name and class_name then
		local import_path = find_import_of_object(object_name)

		if import_path then
			-- Open the CSS file and search for the class definition
			vim.cmd("edit " .. import_path)
			vim.cmd("normal! /\\." .. class_name .. "\\C\\<CR>")
		else
			print("Import not found")
		end
	else
		print("Could not identify object and class name")
	end
end

return find_class_definition
