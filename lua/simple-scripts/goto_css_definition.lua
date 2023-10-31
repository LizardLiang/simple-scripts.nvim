local json = require("json") -- You'll need a JSON library to parse tsconfig.json

local function read_tsconfig()
	local root_dir = vim.fn.getcwd()
	local tsconfig_path = root_dir .. "/tsconfig.json"
	local tsconfig_str = table.concat(vim.fn.readfile(tsconfig_path), "\n")
	return json.decode(tsconfig_str)
end

local function resolve_alias(path)
	local tsconfig = read_tsconfig()
	if not tsconfig or not tsconfig.compilerOptions or not tsconfig.compilerOptions.paths then
		return path
	end

	local paths = tsconfig.compilerOptions.paths
	for alias, actual_paths in pairs(paths) do
		alias = string.gsub(alias, "/*$", "") -- Remove trailing slash or asterisk
		if string.find(path, "^" .. alias) then
			local actual_path = actual_paths[1] -- Use the first mapping
			actual_path = string.gsub(actual_path, "/*$", "") -- Remove trailing slash or asterisk
			return string.gsub(path, "^" .. alias, actual_path)
		end
	end

	return path
end

local function find_class_definition()
	local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
	cursor_row = cursor_row - 1 -- Convert to 0-based index

	-- Get the word under the cursor
	local class_name = vim.fn.expand("<cword>")

	-- Search for the import statement in the buffer
	local lines = vim.api.nvim_buf_get_lines(0, 0, cursor_row, false)
	local module_path = nil
	for _, line in ipairs(lines) do
		if string.match(line, "import .* from '(.*)'") then
			module_path = string.match(line, "import .* from '(.*)'")
			break
		elseif string.match(line, "require%('(.*)'%)") then
			module_path = string.match(line, "require%('(.*)'%)")
			break
		end
	end

	if not module_path then
		print("Could not find import or require statement.")
		return
	end

	-- Resolve alias
	module_path = resolve_alias(module_path)

	-- Get the project root directory
	local root_dir = vim.fn.getcwd()

	-- Construct the absolute path to the SCSS file
	local file_path = root_dir .. "/" .. module_path .. ".scss"

	-- Search for the class definition in the SCSS file
	local scss_lines = vim.fn.readfile(file_path)
	for i, line in ipairs(scss_lines) do
		if string.match(line, "%." .. class_name) then
			-- Open the file and jump to the line
			vim.api.nvim_command("e " .. file_path)
			vim.api.nvim_command("normal! " .. i .. "G")
			return
		end
	end

	print("Could not find class definition.")
end

return find_class_definition
