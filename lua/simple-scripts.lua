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

M.insert_debug_message = function()
	local filetype = vim.bo.filetype
	local line_number = vim.fn.line(".")
	local file_name = vim.fn.expand("%:t")
	local word_under_cursor = vim.fn.expand("<cword>")

	local debug_message = ""

	local jsFileType = { "javascript", "typescript", "javascriptreact", "typescriptreact" }
	local header_extensions = { "h", "hpp", "hxx" }

	if vim.tbl_contains(jsFileType, filetype) then
		debug_message = string.format(
			'console.log("File: %s, Line: %s, %s: ", %s);',
			file_name,
			line_number,
			word_under_cursor,
			word_under_cursor
		)
	elseif filetype == "python" then
		debug_message = string.format(
			'print("File: %s, Line: %s, %s: ", %s)',
			file_name,
			line_number,
			word_under_cursor,
			word_under_cursor
		)
	elseif filetype == "cpp" then
		debug_message = string.format(
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

		-- Check if inside a block
		local line_content = vim.fn.getline(".")
		local open_brace = string.find(line_content, "{")
		local close_brace = string.find(line_content, "}")

		if open_brace and not close_brace then
			-- If inside a block, move the row to before the closing brace
			row = vim.fn.search("}", "nW") + 1
		end

		vim.api.nvim_buf_set_lines(buf, row, row, false, { debug_message })
	end
end

return M
