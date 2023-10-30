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
			if line:match("^simple%-scripts:") then
				in_simple_scripts = true
			elseif line:match("^[a-zA-Z]") then -- Start of a new section
				in_simple_scripts = false
			end
			if in_simple_scripts and line:match('function:%s*"(.+)"') then
				return line:match('function:%s*"(.+)"')
			end
		end
	end
	return nil
end

M.insert_debug_message = function()
	local custom_function = read_project_toml()
	local filetype = vim.bo.filetype
	local line_number = vim.fn.line(".")
	local file_name = vim.fn.expand("%:t")
	local word_under_cursor = vim.fn.expand("<cword>")

	local debug_message = ""

	if filetype == "javascript" then
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
		local row = vim.fn.line(".")
		local buf = vim.api.nvim_get_current_buf()

		local open_brace = vim.fn.search("{", "bcnW")
		local close_brace = vim.fn.search("}", "nW")

		if open_brace and close_brace and close_brace > open_brace then
			row = close_brace
		end

		vim.api.nvim_buf_set_lines(buf, row, row, false, { debug_message })
	end
end

return M
