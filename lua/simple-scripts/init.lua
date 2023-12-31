local find_class_definition = require("simple-scripts.goto_css_definition")
local M = {}

M.toggle = function()
	local filename = vim.fn.expand("%:t:r")
	local extension = vim.fn.expand("%:e")
	local dir = vim.fn.expand("%:p:h")

	local source_extensions = { "cpp", "cc", "c" }
	local header_extensions = { "h", "hpp", "hxx" }

	local function find_and_open_file(dir, filename, extensions)
		for _, ext in ipairs(extensions) do
			local found_files = vim.fn.glob(dir .. "/" .. filename .. "." .. ext)
			if found_files ~= "" then
				local first_found = string.match(found_files, "[^\n]+")
				vim.cmd("edit " .. first_found)
				return true
			end
		end
		return false
	end

	local function switch_dir(dir)
		if string.find(dir, "/source/") then
			return string.gsub(dir, "/source/", "/include/")
		elseif string.find(dir, "/include/") then
			return string.gsub(dir, "/include/", "/source/")
		else
			return dir
		end
	end

	local target_dir = switch_dir(dir)

	if vim.tbl_contains(source_extensions, extension) then
		find_and_open_file(target_dir, filename, header_extensions)
	elseif vim.tbl_contains(header_extensions, extension) then
		find_and_open_file(target_dir, filename, source_extensions)
	end
end

M.generate_cpp_header = function()
	local line = vim.fn.getline(".")
	local match = string.match(line, "([%w%s_:]+[%*%&]?[%s]*[%w_]+)%(.*%)%s*{")
	if match then
		local return_type_and_name, params = string.match(line, "([%w%s_:]+[%*%&]?[%s]*[%w_]+)%((.*)%)%s*{")
		-- Separate the return type and function name
		local return_type, func_name_with_namespace =
			string.match(return_type_and_name, "([%w%s_:]+[%*%&]?[%s]+)([%w_:]+)")
		-- Remove the namespace from the function name, if present
		local func_name = string.match(func_name_with_namespace, "([^:]+)$") or func_name_with_namespace
		local declaration = return_type .. func_name .. "(" .. params .. ");"
		local buf = vim.api.nvim_get_current_buf()
		local row = vim.fn.line(".")
		vim.api.nvim_buf_set_lines(buf, row, row, false, { declaration })
	else
		print("Not a valid C++ function definition.")
	end
end

local function read_project_toml()
	local project_dir = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h")
	local toml_file = project_dir .. "/project.toml"
	if vim.fn.filereadable(toml_file) == 1 then
		local lines = vim.fn.readfile(toml_file)
		local in_simple_scripts = false
		for _, line in ipairs(lines) do
			if line:match("^%[simple%-scripts%]") then
				in_simple_scripts = true
			elseif line:match("^%[") then -- Start of a new section
				if in_simple_scripts then
					return nil -- Exit early if exiting [simple-scripts] without finding function
				end
				in_simple_scripts = false
			end
			if in_simple_scripts and line:match('^function%s*=%s*"(.+)"') then
				return line:match('^function%s*=%s*"(.+)"')
			end
		end
	end
	return nil
end

-- Function to find the nearest function block using Tree-sitter
local function find_function_node()
	local original_filetype = vim.bo.filetype
	local parser_filetype = original_filetype == "typescriptreact" and "typescript" or original_filetype

	local parser = vim.treesitter.get_parser(0, parser_filetype)
	local tree = parser:parse()[1]
	local root = tree:root()
	local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
	cursor_row = cursor_row - 1

	local function_node = nil
	local PREPEND = "prepend"
	local APPEND = "append"
	local prepend_table =
		{ "parameter_list", "argument_list", "object", "arguments", "field_expression", "call_expression" }
	local append_table = { "variable_declarator", "subscript_expression", "parameter_declaration" }
	local insert_direction = APPEND

	local node = root:descendant_for_range(cursor_row, cursor_col, cursor_row, cursor_col)

	while node do
		local node_type = node:type()

		function_node = node
		if vim.tbl_contains(prepend_table, node_type) or string.match(node_type, "statement") then
			insert_direction = PREPEND
			break
		elseif vim.tbl_contains(append_table, node_type) then
			insert_direction = APPEND
			break
		end
		function_node = nil

		node = node:parent()
	end

	return function_node, insert_direction
end

local function find_function_call()
	local original_filetype = vim.bo.filetype
	local parser_filetype = original_filetype == "typescriptreact" and "typescript" or original_filetype

	local parser = vim.treesitter.get_parser(0, parser_filetype)
	local tree = parser:parse()[1]
	local root = tree:root()
	local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
	cursor_row = cursor_row - 1

	local node = root:descendant_for_range(cursor_row, cursor_col, cursor_row, cursor_col)

	local node_type = node:type()
	local parent_node = node:parent()
	local node_parent_type = parent_node and parent_node:type() or ""

	if node_type == "call_expression" or node_parent_type == "argument_list" then
		local start_row, start_col, end_row, end_col = node:range()
		local line = vim.api.nvim_buf_get_lines(0, start_row, end_row + 1, false)[1]
		local function_call_str = string.sub(line, start_col + 1, end_col)
		return function_call_str
	elseif node_parent_type == "call_expression" then
		local start_row, start_col, end_row, end_col = node:parent():range()
		local line = vim.api.nvim_buf_get_lines(0, start_row, end_row + 1, false)[1]
		local function_call_str = string.sub(line, start_col + 1, end_col)
		return function_call_str
	elseif vim.tbl_contains({ "c", "cpp" }, parser_filetype) and node:parent():parent():type() == "call_expression" then
		local start_row, start_col, end_row, end_col = node:parent():parent():range()
		local line = vim.api.nvim_buf_get_lines(0, start_row, end_row + 1, false)[1]
		local function_call_str = string.sub(line, start_col + 1, end_col)
		return function_call_str
	end

	return nil
end

M.insert_debug_message = function()
	local custom_function = read_project_toml()
	local filetype = vim.bo.filetype
	local line_number = vim.fn.line(".")
	local file_name = vim.fn.expand("%:t")
	local word_under_cursor = vim.fn.expand("<cword>")

	local word_node = find_function_call()
	if word_node then
		word_under_cursor = word_node
	end

	local debug_message = ""

	local js_like_languages = { "javascript", "typescript", "javascriptreact", "typescriptreact" }

	if vim.tbl_contains(js_like_languages, filetype) then
		debug_message = custom_function
				and string.format(
					'%s("File: %s, Line: %s, %s: ", %s);',
					custom_function,
					file_name,
					line_number,
					word_under_cursor,
					word_under_cursor
				)
			or string.format(
				'console.log("File: %s, Line: %s, %s: ", %s);',
				file_name,
				line_number,
				word_under_cursor,
				word_under_cursor
			)
	elseif filetype == "python" then
		debug_message = custom_function
				and string.format(
					'%s("File: %s, Line: %s, %s: ", %s)',
					custom_function,
					file_name,
					line_number,
					word_under_cursor,
					word_under_cursor
				)
			or string.format(
				'print("File: %s, Line: %s, %s: ", %s)',
				file_name,
				line_number,
				word_under_cursor,
				word_under_cursor
			)
	elseif filetype == "cpp" then
		debug_message = custom_function
				and string.format(
					'%s << "File: %s, Line: %s, %s: " << %s << std::endl;',
					custom_function,
					file_name,
					line_number,
					word_under_cursor,
					word_under_cursor
				)
			or string.format(
				'std::cout << "File: %s, Line: %s, %s: " << %s << std::endl;',
				file_name,
				line_number,
				word_under_cursor,
				word_under_cursor
			)
	end

	if debug_message ~= "" then
		local function_node, insert_direction = find_function_node()
		local row = vim.fn.line(".")
		local buf = vim.api.nvim_get_current_buf()

		if not function_node then
			vim.api.nvim_buf_set_lines(buf, row, row, false, { debug_message })
			return
		end

		local start_row, _, end_row, _ = function_node:range()

		if insert_direction == "prepend" then
			row = start_row
		else
			-- Insert the debug message at the end of the function block
			row = end_row + 1
		end

		vim.api.nvim_buf_set_lines(buf, row, row, false, { debug_message })
	end
end

M.goto_css_definition = find_class_definition

return M
