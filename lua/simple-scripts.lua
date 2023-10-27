local M = {}

local source_ext = { "cpp", "cc", "c" }
local header_ext = { "h", "hpp" }

M.toggle = function()
	local filename = vim.fn.expand("%:t:r")
	local extension = vim.fn.expand("%:e")

	if vim.tbl_contains(source_ext, extension) then
		for _, ext in ipairs(source_ext) do
			if vim.fn.filereadable(filename .. "." .. ext) == 1 then
				vim.cmd("find " .. filename .. "." .. ext)
				return
			end
		end
	elseif vim.tbl_contains(header_ext, extension) then
		for _, ext in ipairs(header_ext) do
			if vim.fn.filereadable(filename .. "." .. ext) == 1 then
				vim.cmd("find " .. filename .. "." .. ext)
				return
			end
		end
	end
end

return M
