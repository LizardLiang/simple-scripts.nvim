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
	local lines = vim.fn.getline(".", vim.fn.line("'}'"))
	local definition = table.concat(lines, " ")
	local match = string.match(definition, "([%w%s]+[%*%&]?[%s]+[%w_]+)%(.*%)%s*{")
	if match then
		local declaration = string.gsub(match, "{", ";")
		vim.cmd("normal! o")
		vim.fn.appendline(declaration)
	else
		print("Not a valid C++ function definition.")
	end
end

return M
