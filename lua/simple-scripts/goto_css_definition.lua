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
		for alias, paths in pairs(tsconfig.compilerOptions.paths) do
			print(alias, path)
			if string.match(path, "^" .. alias:gsub("%*", ".*")) then
				local actual_path = paths[1]:gsub("%*", import_path:match(alias:gsub("%*", "(.*)")))
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
		print(node)
		local parent = node:parent()
		if node:type() == "identifier" or node:type() == "type_identifier" then
			node = parent
		elseif parent and parent:type() == "member_expression" then
			node = parent
		elseif node:type() == "string" and parent:type() == "subscript_expression" then
			node = parent
		else
			break
		end
	end
	return vim.treesitter.get_node_text(node, 0)
end

local function jump_to_class_definition(file_path, class_name)
	local f = io.open(file_path, "r")
	if f then
		local line_number = 0
		local pattern = "%." .. class_name .. "[%s{]"
		for line in f:lines() do
			line_number = line_number + 1
			if line:find(pattern) then
				f:close()
				vim.cmd("edit " .. file_path)
				vim.cmd("normal " .. line_number .. "G")
				return
			end
		end
		f:close()
	else
		print("Could not open file: " .. file_path)
	end
end

local find_class_name = function(content)
	local object_name, class_name

	object_name, class_name = content:match("([%w_]+)%s*%.%s*([%w_]+)")

	print(object_name, class_name)

	if object_name == nil and class_name == nil then
		object_name, class_name = content:match('([%w_]+)%["([%w%-_]+)"%]')
		print(object_name, class_name)
	end

	return object_name, class_name
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
		print(content)
		object_name, class_name = find_class_name(content)
	end

	if object_name and class_name then
		local import_path = find_import_of_object(object_name)

		if import_path then
			-- Open the CSS file and search for the class definition
			jump_to_class_definition(import_path, class_name)
		else
			print("Import not found")
		end
	else
		print("Could not identify object and class name")
	end
end

return find_class_definition
