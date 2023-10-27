local M = {}

M.toggle = function()
	local filename = vim.fn.expand("%:t:r")
	local extension = vim.fn.expand("%:e")
	local dir = vim.fn.expand("%:p:h") .. "/"

	local source_extensions = { "cpp", "cc", "c" }
	local header_extensions = { "h", "hpp", "hxx" }

	local function find_file_in_dir_and_subdir(filename, extensions)
		for _, ext in ipairs(extensions) do
			local found_files = vim.fn.glob(dir .. "**/" .. filename .. "." .. ext)
			if found_files ~= "" then
				local first_found = string.match(found_files, "[^\n]+")
				vim.cmd("edit " .. first_found)
				return true
			end
		end
		return false
	end

	if vim.tbl_contains(source_extensions, extension) then
		find_file_in_dir_and_subdir(filename, header_extensions)
	elseif vim.tbl_contains(header_extensions, extension) then
		find_file_in_dir_and_subdir(filename, source_extensions)
	end
end

return M
